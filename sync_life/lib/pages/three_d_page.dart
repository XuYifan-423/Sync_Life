import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:vector_math/vector_math.dart' as vm;

// API配置类
class ApiConfig {
  // API基础地址
  // 注意：在手机上测试时，需要使用电脑的局域网IP地址
  static const String baseUrl = 'http://192.168.118.186:8000/api';
  
  // 登录接口
  static const String loginUrl = '$baseUrl/posture/login/';
  
  // 注册接口
  static const String registerUrl = '$baseUrl/posture/register/';
  
  // 发送验证码接口
  static const String sendCodeUrl = '$baseUrl/posture/send-code/';
  
  // N8N处理消息接口
  static const String n8nUrl = '$baseUrl/posture/n8n/';
  
  // 蓝牙数据接口
  static const String bluetoothUrl = '$baseUrl/posture/bluetooth/';
}



class ThreeDPage extends StatefulWidget {
  const ThreeDPage({super.key});

  @override
  ThreeDPageState createState() => ThreeDPageState();
}

class ThreeDPageState extends State<ThreeDPage> {
  // 蓝牙连接状态
  bool _isBluetoothConnected = false;
  // 设备名称
  String _deviceName = '未连接设备';
  // 校准状态
  bool _isCalibrated = false;
  // 姿态状态
  String _postureState = '初始化';
  // 仰俯角
  double _pitchAngle = 0.0;
  // 横滚角
  double _rollAngle = 0.0;
  // 偏航角
  double _yawAngle = 0.0;
  // 风险等级
  String _riskLevel = '正常';
  // 蓝牙设备
  BluetoothDevice? _connectedDevice;
  // 蓝牙服务
  BluetoothService? _bluetoothService;
  // 蓝牙特征值
  BluetoothCharacteristic? _postureCharacteristic;
  // 数据传输定时器
  Timer? _dataTransmitTimer;
  // 3D模型状态
  bool _isModelLoaded = false;

  @override
  void initState() {
    super.initState();
    // 读取保存的设备连接状态
    _loadSavedDeviceConnectionStatus();
    // 启动定期获取姿态数据的任务
    _startFetchingPostureData();
    // 自动扫描蓝牙设备
    Future.delayed(Duration(seconds: 2), () {
      _scanForDevices();
    });
    // 模拟3D模型加载完成
    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        _isModelLoaded = true;
      });
    });
  }
  
  // 读取保存的设备连接状态并检查实际连接状态
  Future<void> _loadSavedDeviceConnectionStatus() async {
    try {
      // 1. 首先读取保存的设备连接状态
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool? isDeviceConnected = prefs.getBool('isDeviceConnected');
      String? deviceName = prefs.getString('deviceName');
      
      if (isDeviceConnected != null && deviceName != null) {
        print('读取保存的设备连接状态: $isDeviceConnected, $deviceName');
      }
      
      // 2. 然后检查实际的蓝牙连接状态
      bool isBluetoothOn = false;
      try {
        isBluetoothOn = await FlutterBluePlus.isOn;
      } catch (e) {
        print('检查蓝牙状态时出错: $e');
      }
      
      if (isBluetoothOn) {
        // 获取已连接的设备列表
        List<BluetoothDevice> connectedDevices = [];
        try {
          connectedDevices = FlutterBluePlus.connectedDevices;
        } catch (e) {
          print('获取已连接设备列表时出错: $e');
        }
        
        if (connectedDevices.isNotEmpty) {
          // 实际有设备连接，更新状态
          setState(() {
            _isBluetoothConnected = true;
            _deviceName = connectedDevices.first.name.isEmpty ? '未知设备' : connectedDevices.first.name;
          });
          print('实际检测到已连接的设备: $_deviceName');
        } else {
          // 实际没有设备连接，更新状态
          setState(() {
            _isBluetoothConnected = false;
            _deviceName = '未连接设备';
          });
          print('实际检测到未连接设备');
        }
      } else {
        // 蓝牙未开启，更新状态
        setState(() {
          _isBluetoothConnected = false;
          _deviceName = '未连接设备';
        });
        print('蓝牙未开启');
      }
    } catch (error) {
      print('读取设备连接状态时出错: $error');
    }
  }

  // 扫描蓝牙设备
  void _scanForDevices() {
    print('开始扫描蓝牙设备...');
    // 停止之前的扫描
    FlutterBluePlus.stopScan();
    // 开始新的扫描
    FlutterBluePlus.startScan(timeout: Duration(seconds: 4));
    // 监听扫描结果
    FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        print('发现设备: ${result.device.name}, RSSI: ${result.rssi}, UUID: ${result.device.id}');
        // 连接到名称为 SmartWear 的设备（蓝牙衣服设备）
        if (result.device.name == 'SmartWear') {
          print('连接到蓝牙衣服设备: ${result.device.name}');
          // 停止扫描
          FlutterBluePlus.stopScan();
          // 连接设备
          _connectToDevice(result.device);
        }
      }
    });
    // 监听扫描完成
    FlutterBluePlus.isScanning.listen((isScanning) {
      if (!isScanning) {
        print('扫描完成');
        // 只有在校准后才尝试重连
        if (!_isBluetoothConnected && _isCalibrated) {
          print('未找到设备，3秒后重新扫描');
          Future.delayed(Duration(seconds: 3), () {
            _scanForDevices();
          });
        }
      }
    });
  }

  // 连接蓝牙设备
  void _connectToDevice(BluetoothDevice device) {
    print('连接到设备: ${device.name}');
    device.connect(autoConnect: true).then((_) {
      print('设备连接成功: ${device.name}');
      setState(() {
        _isBluetoothConnected = true;
        _deviceName = device.name;
        _connectedDevice = device;
      });
      // 发现服务
      _discoverServices(device);
    }).catchError((error) {
      print('设备连接失败: $error');
      setState(() {
        _isBluetoothConnected = false;
        _deviceName = '连接失败';
      });
      // 只有在校准后才尝试重连
      if (_isCalibrated) {
        // 尝试重连
        Future.delayed(Duration(seconds: 3), () {
          _scanForDevices();
        });
      }
    });
    // 监听连接状态
    device.connectionState.listen((state) {
      print('设备连接状态: $state');
      if (state == BluetoothConnectionState.connected) {
        print('设备已连接');
        setState(() {
          _isBluetoothConnected = true;
          _deviceName = device.name;
          _connectedDevice = device;
        });
      } else if (state == BluetoothConnectionState.disconnected) {
        print('设备断开连接');
        setState(() {
          _isBluetoothConnected = false;
          _deviceName = '未连接设备';
          _connectedDevice = null;
          _bluetoothService = null;
          _postureCharacteristic = null;
        });
        // 只有在校准后才尝试重连
        if (_isCalibrated) {
          // 尝试重连
          Future.delayed(Duration(seconds: 3), () {
            _scanForDevices();
          });
        }
      }
    });
  }

  // 发现蓝牙服务
  void _discoverServices(BluetoothDevice device) {
    print('发现设备服务...');
    device.discoverServices().then((services) {
      for (var service in services) {
        print('服务: ${service.uuid}');
        // 查找特征值
        for (var characteristic in service.characteristics) {
          print('特征值: ${characteristic.uuid}');
          // 查找姿态数据特征值 (adaf0101-c332-42a8-93bd-25e905756cb8)
          if (characteristic.uuid.toString() == 'adaf0101-c332-42a8-93bd-25e905756cb8') {
            print('找到姿态数据特征值');
            setState(() {
              _bluetoothService = service;
              _postureCharacteristic = characteristic;
            });
            // 启用通知
            characteristic.setNotifyValue(true);
            // 监听特征值变化
            characteristic.value.listen((value) {
              print('接收到蓝牙数据: $value');
              // 处理接收到的数据
              _processBluetoothData(value);
            });
          }
        }
      }
    }).catchError((error) {
      print('发现服务失败: $error');
    });
  }

  // 处理蓝牙数据
  void _processBluetoothData(List<int> value) {
    // 只有在校准状态为已校准的情况下才处理蓝牙数据
    if (!_isCalibrated) {
      print('校准状态未完成，暂不处理蓝牙数据');
      return;
    }
    
    // 只有在蓝牙连接状态为已连接的情况下才处理蓝牙数据
    if (!_isBluetoothConnected) {
      print('蓝牙未连接，暂不处理蓝牙数据');
      return;
    }
    
    // 检查数据长度是否足够
    if (value.length < 8) {
      print('原始蓝牙数据长度不足，暂不处理蓝牙数据');
      return;
    }
    
    try {
      // 直接处理蓝牙数据，不发送到后端
      print('原始蓝牙数据长度: ${value.length}');
      
      // 解析蓝牙数据并更新姿态
      _parseBluetoothData(value);
    } catch (error) {
      print('处理蓝牙数据失败: $error');
    }
  }
  
  // 解析蓝牙数据
  void _parseBluetoothData(List<int> value) {
    // 解析蓝牙数据，提取姿态信息
    // 假设蓝牙数据格式为: [pitch, roll, yaw, ...]
    // 这里使用简单的解析方法，实际解析方法需要根据蓝牙设备的数据格式进行调整
    double pitch = _bytesToFloat(value.sublist(0, 4));
    double roll = _bytesToFloat(value.sublist(4, 8));
    double yaw = 0.0;
    if (value.length >= 12) {
      yaw = _bytesToFloat(value.sublist(8, 12));
    }
    
    // 更新姿态数据
    setState(() {
      _pitchAngle = pitch;
      _rollAngle = roll;
      _yawAngle = yaw;
      // 根据姿态数据更新状态和风险等级
      _updatePostureState(pitch, roll, yaw);
    });
    
    print('解析后的姿态数据: pitch=$pitch, roll=$roll, yaw=$yaw');
  }
  
  // 根据姿态数据更新状态和风险等级
  void _updatePostureState(double pitch, double roll, double yaw) {
    // 计算姿态偏差
    double pitchAbs = pitch.abs();
    double rollAbs = roll.abs();
    double yawAbs = yaw.abs();
    
    // 根据姿态偏差更新状态和风险等级
    if (pitchAbs < 10 && rollAbs < 10 && yawAbs < 10) {
      _postureState = '正常';
      _riskLevel = '正常';
    } else if (pitchAbs < 20 && rollAbs < 20 && yawAbs < 20) {
      _postureState = '轻微异常';
      _riskLevel = '低风险';
    } else {
      _postureState = '严重异常';
      _riskLevel = '高风险';
    }
  }
  
  // 将4字节转换为float
  double _bytesToFloat(List<int> bytes) {
    if (bytes.length != 4) {
      return 0.0;
    }
    
    int bits = (bytes[0] & 0xFF) << 24 |
               (bytes[1] & 0xFF) << 16 |
               (bytes[2] & 0xFF) << 8 |
               (bytes[3] & 0xFF);
    
    // 处理符号位
    int sign = (bits >> 31) & 1;
    // 处理指数位
    int exponent = (bits >> 23) & 0xFF;
    // 处理尾数位
    int mantissa = bits & 0x7FFFFF;
    
    // 计算float值
    if (exponent == 0 && mantissa == 0) {
      return sign == 0 ? 0.0 : -0.0;
    }
    
    double value = 1.0;
    for (int i = 0; i < 23; i++) {
      if ((mantissa >> (22 - i)) & 1 == 1) {
        value += pow(2, -23 + i);
      }
    }
    
    value *= pow(2, exponent - 127);
    return sign == 0 ? value : -value;
  }

  // 开始校准
  void _startCalibration() {
    // 检查蓝牙连接状态
    if (!_isBluetoothConnected) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('校准失败'),
          content: const Text('蓝牙未连接，无法进行校准！'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('正在校准'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('3'),
          ],
        ),
      ),
    );
    
    // 倒计时
    for (int i = 3; i > 0; i--) {
      Future.delayed(Duration(seconds: 3 - i), () {
        if (mounted) {
          Navigator.pop(context);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('正在校准'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('$i'),
                ],
              ),
            ),
          );
        }
      });
    }
    
    // 校准完成
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pop(context);
        // 设置校准状态为已校准
        setState(() {
          _isCalibrated = true;
        });
        // 显示校准完成提示
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('校准完成'),
            content: const Text('成功完成校准！'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    });
  }

  // 开始定期获取姿态数据
  void _startFetchingPostureData() {
    // 每1秒获取一次姿态数据
    _dataTransmitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // 不再从后端获取数据，而是直接从蓝牙设备获取数据
      // _fetchPostureData();
      // 添加模拟数据，用于测试模型动画
      _simulatePostureData();
    });
  }
  
  // 模拟姿态数据，用于测试模型动画
  void _simulatePostureData() {
    // 只有在校准状态为已校准的情况下才模拟数据
    if (!_isCalibrated) {
      return;
    }
    
    // 生成随机的姿态数据，用于测试模型动画
    setState(() {
      _pitchAngle = sin(DateTime.now().millisecondsSinceEpoch / 1000) * 15;
      _rollAngle = cos(DateTime.now().millisecondsSinceEpoch / 1000) * 15;
      _yawAngle = sin(DateTime.now().millisecondsSinceEpoch / 2000) * 10;
      // 根据姿态数据更新状态和风险等级
      _updatePostureState(_pitchAngle, _rollAngle, _yawAngle);
    });
  }

  @override
  void dispose() {
    // 清理资源
    if (_dataTransmitTimer != null) {
      _dataTransmitTimer!.cancel();
    }
    // 断开蓝牙连接
    if (_connectedDevice != null) {
      _connectedDevice!.disconnect();
    }
    // 停止蓝牙扫描
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 添加与其他页面一致的AppBar
      appBar: AppBar(
        title: const Text('3D展示'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: null,
      ),
      body: Stack(
        children: [
          // 背景图片
          Image(image: AssetImage('assets/background.png'), width: double.infinity, height: double.infinity, fit: BoxFit.cover),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                ],
              ),
            ),
            child: Column(
              children: [
                // 主体内容
                Expanded(
                  child: Row(
                    children: [
                      // 左侧提示信息
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '设备状态',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // 连接状态
                              Row(
                                children: [
                                  Icon(
                                    _isBluetoothConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                                    color: _isBluetoothConnected ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isBluetoothConnected ? '已连接' : '未连接',
                                    style: TextStyle(
                                      color: _isBluetoothConnected ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              
                              // 设备名称
                              Text(
                                '设备: $_deviceName',
                                style: const TextStyle(color: Colors.white),
                              ),
                              
                              // 校准状态
                              Text(
                                '校准: ${_isCalibrated ? '已校准' : '未校准'}',
                                style: TextStyle(
                                  color: _isCalibrated ? Colors.green : Colors.orange,
                                ),
                              ),
                              
                              // 姿态状态
                              Text(
                                '姿态: $_postureState',
                                style: TextStyle(
                                  color: _postureState == '正常' ? Colors.green : (_postureState == '轻微异常' ? Colors.orange : Colors.red),
                                ),
                              ),
                              
                              // 风险等级
                              Text(
                                '风险: $_riskLevel',
                                style: TextStyle(
                                  color: _riskLevel == '正常' ? Colors.green : (_riskLevel == '低风险' ? Colors.orange : Colors.red),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              const Text(
                                '操作提示',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                             
                              const SizedBox(height: 16),
                               Icon(Icons.accessibility, color: Colors.blue),
                              const Text(
                                '请在连接好衣服裤子两个设备后，站好将双臂水平展开，点击开始校准\n• 保持自然姿态\n• 避免快速移动\n• 如需重新校准，请点击下方按钮',
                                style: TextStyle(color: Colors.white70),
                              ),
                              
                              const Spacer(),
                              
                              // 校准按钮
                              ElevatedButton(
                                onPressed: () {
                                  // 开始校准
                                  _startCalibration();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A90E2),
                                ),
                                child: const Text('开始校准'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // 右侧3D展示
                      Expanded(
                        flex: 2,
                        child: Container(
                          child: Center(
                            child: _isCalibrated ?
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 400,
                                    height: 500,
                                    child: _isModelLoaded ?
                                      CustomPaint(
                                        painter: HumanBodyPainter(
                                          pitch: _pitchAngle,
                                          roll: _rollAngle,
                                          yaw: _yawAngle,
                                        ),
                                      ) :
                                      Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                  ),
                                  SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: () {
                                      // 这里可以添加额外的控制逻辑
                                      print('刷新3D模型');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4A90E2),
                                    ),
                                    child: const Text('刷新3D模型'),
                                  ),
                                ],
                              ) :
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orange,
                                    size: 48,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '请先进行校准',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    '校准后将显示3D模型',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 人体3D绘制
class HumanBodyPainter extends CustomPainter {
  // 姿态数据
  final double pitch;
  final double roll;
  final double yaw;

  HumanBodyPainter({this.pitch = 0.0, this.roll = 0.0, this.yaw = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    // 基础绘制样式
    final paint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // 节点绘制样式
    final dotPaint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..style = PaintingStyle.fill;

    // 衣服绘制样式
    final clothesPaint = Paint()
      ..color = Color.fromARGB(100, 74, 144, 226)
      ..style = PaintingStyle.fill;

    // 绘制人体轮廓和节点
    const nodeRadius = 5.0;

    // 头部 - 根据姿态数据调整位置
    final headCenter = Offset(
      size.width / 2 + roll * 8, 
      size.height * 0.15 + pitch * 8
    );
    canvas.drawCircle(headCenter, size.width * 0.1, paint);
    canvas.drawCircle(headCenter, nodeRadius, dotPaint);

    // 颈部 - 根据姿态数据调整位置
    final neckCenter = Offset(
      size.width / 2 + roll * 8, 
      size.height * 0.22 + pitch * 8
    );
    canvas.drawCircle(neckCenter, nodeRadius, dotPaint);
    canvas.drawLine(headCenter, neckCenter, paint);

    // 肩部 - 根据姿态数据调整位置
    final leftShoulder = Offset(
      size.width * 0.3 + roll * 15, 
      size.height * 0.28 + pitch * 8
    );
    final rightShoulder = Offset(
      size.width * 0.7 - roll * 15, 
      size.height * 0.28 + pitch * 8
    );
    canvas.drawCircle(leftShoulder, nodeRadius, dotPaint);
    canvas.drawCircle(rightShoulder, nodeRadius, dotPaint);
    canvas.drawLine(neckCenter, leftShoulder, paint);
    canvas.drawLine(neckCenter, rightShoulder, paint);
    canvas.drawLine(leftShoulder, rightShoulder, paint);

    // 胸部 - 根据姿态数据调整位置
    final chestCenter = Offset(
      size.width / 2 + roll * 8, 
      size.height * 0.35 + pitch * 8
    );
    canvas.drawCircle(chestCenter, nodeRadius, dotPaint);
    canvas.drawLine(neckCenter, chestCenter, paint);
    canvas.drawLine(leftShoulder, chestCenter, paint);
    canvas.drawLine(rightShoulder, chestCenter, paint);

    // 腰部 - 根据姿态数据调整位置
    final waistCenter = Offset(
      size.width / 2 + roll * 8, 
      size.height * 0.45 + pitch * 8
    );
    canvas.drawCircle(waistCenter, nodeRadius, dotPaint);
    canvas.drawLine(chestCenter, waistCenter, paint);

    // 髋部 - 根据姿态数据调整位置
    final leftHip = Offset(
      size.width * 0.4 + roll * 12, 
      size.height * 0.55 + pitch * 8
    );
    final rightHip = Offset(
      size.width * 0.6 - roll * 12, 
      size.height * 0.55 + pitch * 8
    );
    canvas.drawCircle(leftHip, nodeRadius, dotPaint);
    canvas.drawCircle(rightHip, nodeRadius, dotPaint);
    canvas.drawLine(waistCenter, leftHip, paint);
    canvas.drawLine(waistCenter, rightHip, paint);
    canvas.drawLine(leftHip, rightHip, paint);

    // 左臂 - 根据姿态数据调整位置
    final leftElbow = Offset(
      size.width * 0.2 + roll * 20, 
      size.height * 0.4 + pitch * 20
    );
    final leftWrist = Offset(
      size.width * 0.1 + roll * 25, 
      size.height * 0.5 + pitch * 25
    );
    canvas.drawCircle(leftElbow, nodeRadius, dotPaint);
    canvas.drawCircle(leftWrist, nodeRadius, dotPaint);
    canvas.drawLine(leftShoulder, leftElbow, paint);
    canvas.drawLine(leftElbow, leftWrist, paint);

    // 右臂 - 根据姿态数据调整位置
    final rightElbow = Offset(
      size.width * 0.8 - roll * 20, 
      size.height * 0.4 + pitch * 20
    );
    final rightWrist = Offset(
      size.width * 0.9 - roll * 25, 
      size.height * 0.5 + pitch * 25
    );
    canvas.drawCircle(rightElbow, nodeRadius, dotPaint);
    canvas.drawCircle(rightWrist, nodeRadius, dotPaint);
    canvas.drawLine(rightShoulder, rightElbow, paint);
    canvas.drawLine(rightElbow, rightWrist, paint);

    // 左腿 - 根据姿态数据调整位置
    final leftKnee = Offset(
      size.width * 0.35 + roll * 15, 
      size.height * 0.7 + pitch * 15
    );
    final leftAnkle = Offset(
      size.width * 0.4 + roll * 20, 
      size.height * 0.9 + pitch * 20
    );
    canvas.drawCircle(leftKnee, nodeRadius, dotPaint);
    canvas.drawCircle(leftAnkle, nodeRadius, dotPaint);
    canvas.drawLine(leftHip, leftKnee, paint);
    canvas.drawLine(leftKnee, leftAnkle, paint);

    // 右腿 - 根据姿态数据调整位置
    final rightKnee = Offset(
      size.width * 0.65 - roll * 15, 
      size.height * 0.7 + pitch * 15
    );
    final rightAnkle = Offset(
      size.width * 0.6 - roll * 20, 
      size.height * 0.9 + pitch * 20
    );
    canvas.drawCircle(rightKnee, nodeRadius, dotPaint);
    canvas.drawCircle(rightAnkle, nodeRadius, dotPaint);
    canvas.drawLine(rightHip, rightKnee, paint);
    canvas.drawLine(rightKnee, rightAnkle, paint);

    // 连接线
    canvas.drawLine(chestCenter, leftShoulder, paint);
    canvas.drawLine(chestCenter, rightShoulder, paint);
    canvas.drawLine(waistCenter, leftHip, paint);
    canvas.drawLine(waistCenter, rightHip, paint);

    // 绘制衣服 - 上衣
    final clothesPath = Path();
    clothesPath.moveTo(leftShoulder.dx, leftShoulder.dy);
    clothesPath.lineTo(leftShoulder.dx - 10, leftShoulder.dy + 30);
    clothesPath.lineTo(waistCenter.dx - 15, waistCenter.dy + 20);
    clothesPath.lineTo(waistCenter.dx + 15, waistCenter.dy + 20);
    clothesPath.lineTo(rightShoulder.dx + 10, rightShoulder.dy + 30);
    clothesPath.lineTo(rightShoulder.dx, rightShoulder.dy);
    clothesPath.close();
    canvas.drawPath(clothesPath, clothesPaint);

    // 绘制衣服 - 裤子
    final pantsPath = Path();
    pantsPath.moveTo(leftHip.dx, leftHip.dy);
    pantsPath.lineTo(leftHip.dx - 5, leftHip.dy + 20);
    pantsPath.lineTo(leftKnee.dx - 5, leftKnee.dy);
    pantsPath.lineTo(leftKnee.dx, leftKnee.dy + 10);
    pantsPath.lineTo(leftAnkle.dx - 5, leftAnkle.dy);
    pantsPath.lineTo(rightAnkle.dx + 5, rightAnkle.dy);
    pantsPath.lineTo(rightKnee.dx, rightKnee.dy + 10);
    pantsPath.lineTo(rightKnee.dx + 5, rightKnee.dy);
    pantsPath.lineTo(rightHip.dx + 5, rightHip.dy + 20);
    pantsPath.lineTo(rightHip.dx, rightHip.dy);
    pantsPath.close();
    canvas.drawPath(pantsPath, clothesPaint);

    // 绘制蓝牙传感器位置
    final sensorPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // 肩部传感器
    canvas.drawCircle(leftShoulder, nodeRadius - 1, sensorPaint);
    canvas.drawCircle(rightShoulder, nodeRadius - 1, sensorPaint);

    // 肘部传感器
    canvas.drawCircle(leftElbow, nodeRadius - 1, sensorPaint);
    canvas.drawCircle(rightElbow, nodeRadius - 1, sensorPaint);

    // 腰部传感器
    canvas.drawCircle(waistCenter, nodeRadius - 1, sensorPaint);

    // 膝盖传感器
    canvas.drawCircle(leftKnee, nodeRadius - 1, sensorPaint);
    canvas.drawCircle(rightKnee, nodeRadius - 1, sensorPaint);

    // 绘制姿态状态指示器
    final statePaint = Paint()
      ..color = _getStateColor()
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.1), 10, statePaint);
  }

  // 根据姿态数据获取状态颜色
  Color _getStateColor() {
    if (pitch.abs() > 30 || roll.abs() > 30) {
      return Colors.red;
    } else if (pitch.abs() > 15 || roll.abs() > 15) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is HumanBodyPainter) {
      return oldDelegate.pitch != pitch || 
             oldDelegate.roll != roll || 
             oldDelegate.yaw != yaw;
    }
    return true;
  }
}
