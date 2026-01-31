import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/api_config.dart';
import '../utils/bluetooth_global_state.dart';

class ProfilePage extends StatefulWidget {
  ProfilePage({super.key});

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final BluetoothGlobalState _bluetoothGlobalState = BluetoothGlobalState();

  // 用户数据
  String _phone = '';
  String _email = '';
  String _password = '********';
  String _identity = '';
  String _ills = '';
  int _age = 0;
  double _height = 0.0;
  double _weight = 0.0;
  bool _isLoading = true;
  bool _isDataLoaded = false;
  int? _userId;
  
  // 蓝牙相关状态
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  
  // 动画控制器
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // 创建淡入动画
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    
    // 创建从上方滑入的动画
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    // 应用启动时检查年龄是否需要更新
    _checkAndUpdateAge();
    // 加载用户ID
    _loadUserId();
    // 直接显示页面，不加载详细信息
    _animationController.forward();
  }

  // 加载用户ID
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    final userIdentifier = prefs.getString('userIdentifier');
    final isLoggedInValue = prefs.getBool('isLoggedIn') ?? false;
    
    print('isLoggedIn: $isLoggedInValue');
    print('userIdentifier: $userIdentifier');
    print('userId: $userId');
    
    if (mounted) {
      setState(() {
        if (userIdentifier != null) {
          _phone = userIdentifier;
        }
        _userId = userId;
        _isLoading = false;
        _isDataLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Image(image: AssetImage('assets/background.png'), width: double.infinity, height: double.infinity, fit: BoxFit.cover),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4A90E2),
                strokeWidth: 4,
              ),
            )
          else if (_isDataLoaded)
            // 使用动画效果显示卡片
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 设备及状态
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.wifi_tethering, color: Color(0xFF4A90E2)),
                        title: const Text('我的设备'),
                        subtitle: Text('${_bluetoothGlobalState.deviceName}          ${_bluetoothGlobalState.isBluetoothConnected ? '已连接' : '未连接'}'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 设备管理逻辑
                          _showDeviceManagementDialog();
                        },
                      ),
                    ),
                    
                    // 手机号
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.phone, color: Color(0xFF4A90E2)),
                        title: const Text('手机号'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 修改手机号逻辑
                          _showChangePhoneDialog();
                        },
                      ),
                    ),
                    
                    // 邮箱
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.email, color: Color(0xFF4A90E2)),
                        title: const Text('邮箱'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 修改邮箱逻辑
                          _showChangeEmailDialog();
                        },
                      ),
                    ),
                    
                    // 年龄
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today, color: Color(0xFF4A90E2)),
                        title: const Text('年龄'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 修改年龄逻辑
                          _showChangeAgeDialog();
                        },
                      ),
                    ),
                    
                    // 身高
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.trending_up, color: Color(0xFF4A90E2)),
                        title: const Text('身高（cm）'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 修改身高逻辑
                          _showChangeHeightDialog();
                        },
                      ),
                    ),
                    
                    // 体重
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.fitness_center, color: Color(0xFF4A90E2)),
                        title: const Text('体重（kg）'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 修改体重逻辑
                          _showChangeWeightDialog();
                        },
                      ),
                    ),
                    
                    // 身份
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.person_outline, color: Color(0xFF4A90E2)),
                        title: const Text('身份'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 修改身份逻辑
                          _showChangeIdentityDialog();
                        },
                      ),
                    ),
                    
                    // 疾病史
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.local_hospital, color: Color(0xFF4A90E2)),
                        title: const Text('疾病史'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 修改疾病史逻辑
                          _showChangeIllsDialog();
                        },
                      ),
                    ),
                    
                    // 密码
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.lock, color: Color(0xFF4A90E2)),
                        title: const Text('密码'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 修改密码逻辑
                          _showChangePasswordDialog();
                        },
                      ),
                    ),
                    
                    // 退出登录
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text('退出登录'),
                        textColor: Colors.red,
                        onTap: () {
                          // 退出登录逻辑
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('退出登录'),
                              content: const Text('确定要退出登录吗？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    // 清除本地存储中的登录状态
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setBool('isLoggedIn', false);
                                    await prefs.remove('userIdentifier');
                                    
                                    // 跳转到登录页面
                                    Navigator.pushReplacementNamed(context, '/login');
                                  },
                                  child: const Text('确定'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // 无数据状态
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('暂无用户信息', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('请先登录后查看个人信息', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('去登录', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 设备管理对话框
  void _showDeviceManagementDialog() async {
    // 获取已连接的设备列表
    List<BluetoothDevice> connectedDevices = [];
    try {
      connectedDevices = FlutterBluePlus.connectedDevices;
    } catch (e) {
      print('获取已连接设备列表时出错: $e');
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.wifi_tethering, color: Color(0xFF4A90E2)),
            SizedBox(width: 8),
            Text('设备管理'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (connectedDevices.isNotEmpty)
              Column(
                children: [
                  const Text('已连接设备:'),
                  const SizedBox(height: 8),
                  ...connectedDevices.map((device) => Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text('设备名称: ${device.name.isEmpty ? '未知设备' : device.name}')),
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.red),
                            onPressed: () async {
                              try {
                                // 断开该设备的连接
                                await device.disconnect();
                                Navigator.pop(context);
                                // 重新显示设备管理对话框，更新设备列表
                                _showDeviceManagementDialog();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('已断开设备 ${device.name} 连接')),
                                );
                              } catch (error) {
                                print('断开设备 ${device.name} 连接时出错: $error');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('断开设备连接失败: $error')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.device_hub, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(child: Text('设备ID: ${device.id}')),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  )).toList(),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.accessibility, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('校准提示'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('请在连接好衣服裤子两个设备后前往模型展示页面校准'),
                ],
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('当前设备: ${_bluetoothGlobalState.deviceName}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('连接状态: ${_bluetoothGlobalState.isBluetoothConnected ? '已连接' : '未连接'}'),
                  const SizedBox(height: 16),
                  Text('搜素设备时，若一次没打开，请多试几次'),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          if (connectedDevices.isNotEmpty)
            TextButton(
              onPressed: () async {
                // 断开所有设备的连接
                for (var device in connectedDevices) {
                  try {
                    await device.disconnect();
                  } catch (error) {
                    print('断开设备 ${device.name} 连接时出错: $error');
                  }
                }
                
                _bluetoothGlobalState.disconnect();
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已断开所有设备连接')),
                );
              },
              child: const Text('断开连接'),
            ),
          TextButton(
            onPressed: () {
              // 搜索蓝牙设备逻辑
              Navigator.pop(context);
              _searchBluetoothDevices();
            },
            child: const Text('搜索设备'),
          ),
        ],
      ),
    );
  }

  // 搜索蓝牙设备
  void _searchBluetoothDevices() async {
    try {
      // 请求必要的权限
      final PermissionStatus locationStatus = await Permission.locationWhenInUse.request();
      if (!locationStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要位置权限才能扫描蓝牙设备')),
        );
        return;
      }
      
      // 检查蓝牙是否开启
      bool isBluetoothOn = false;
      try {
        isBluetoothOn = await FlutterBluePlus.isOn;
      } catch (e) {
        print('检查蓝牙状态时出错: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('检查蓝牙状态失败')),
        );
        return;
      }
      
      if (!isBluetoothOn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先开启蓝牙')),
        );
        return;
      }
      
      // 开始扫描
      setState(() {
        _scanResults = [];
        _isScanning = true;
      });
      
      // 清除之前的扫描结果
      _scanResults.clear();
      
      // 开始扫描，设置超时时间为10秒
      FlutterBluePlus.scanResults.listen(
        (results) {
          if (mounted) {
            // 处理扫描结果，确保已连接的设备显示在上方
            List<ScanResult> processedResults = [];
            List<ScanResult> otherResults = [];
            
            // 遍历扫描结果，分离已连接和未连接的设备
            for (var result in results) {
              bool isConnected = _bluetoothGlobalState.connectedDevice != null && _bluetoothGlobalState.connectedDevice!.id == result.device.id;
              if (isConnected) {
                processedResults.add(result);
              } else {
                otherResults.add(result);
              }
            }
            
            // 检查已连接的设备是否在扫描结果中，如果不在，手动添加
            if (_bluetoothGlobalState.connectedDevice != null) {
              bool isInResults = false;
              for (var result in results) {
                if (result.device.id == _bluetoothGlobalState.connectedDevice!.id) {
                  isInResults = true;
                  break;
                }
              }
              if (!isInResults) {
                // 创建一个虚拟的ScanResult来表示已连接的设备
                // 注意：这只是为了显示目的，实际使用时需要谨慎
                print('已连接的设备不在扫描结果中，手动添加到列表');
              }
            }
            
            // 合并结果，已连接的设备在前
            processedResults.addAll(otherResults);
            
            setState(() {
              _scanResults = processedResults;
            });
          }
        },
        onError: (error) {
          print('扫描错误: $error');
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
          }
        },
      );
      
      // 开始实际的扫描
      try {
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      } catch (e) {
        print('开始扫描出错: $e');
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('开始扫描失败')),
          );
        }
        return;
      }
      
      // 监听扫描状态，当扫描停止时处理结果
      FlutterBluePlus.isScanning.listen((isScanning) {
        if (mounted && !isScanning && _isScanning) {
          print('扫描已停止，找到 ${_scanResults.length} 个设备');
          setState(() {
            _isScanning = false;
          });
          
          if (_scanResults.isEmpty) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('搜索结果'),
                content: const Text('未找到可用的蓝牙设备，请确保设备已开启并处于可发现状态'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('确定'),
                  ),
                ],
              ),
            );
          } else {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('可用设备'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _scanResults.map((result) {
                      // 输出设备详细信息到日志
                      print('设备信息: 名称=${result.device.name}, ID=${result.device.id}, 信号强度=${result.rssi}');
                      
                      // 检查设备是否已连接
                      bool isConnected = _bluetoothGlobalState.connectedDevice != null && _bluetoothGlobalState.connectedDevice!.id == result.device.id;
                      
                      return ListTile(
                        title: Text(result.device.name.isEmpty ? '未知设备' : result.device.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('信号强度: ${result.rssi} dBm'),
                            Text('设备ID: ${result.device.id}'),
                          ],
                        ),
                        trailing: isConnected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                        onTap: () {
                          Navigator.pop(context);
                          _connectToClothingDevice(result.device);
                        },
                      );
                    }).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _searchBluetoothDevices();
                    },
                    child: const Text('刷新'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ],
              ),
            );
          }
        }
      });
    } catch (error) {
      print('搜索蓝牙设备时出错: $error');
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索蓝牙设备时出错: $error')),
        );
      }
    }
  }

  // 连接到普通设备
  void _connectToDevice(String deviceName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已成功连接设备 $deviceName')),
    );
  }

  // 连接到衣物设备
  void _connectToClothingDevice(BluetoothDevice device) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正在连接衣物设备 ${device.name}...')),
      );
      
      // 显示连接进度对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('连接设备'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('正在连接 ${device.name}...'),
              const SizedBox(height: 8),
              const Text('请保持设备在附近并处于可连接状态'),
            ],
          ),
        ),
      );
      
      // 尝试连接设备
      await device.connect(timeout: const Duration(seconds: 15));
      
      // 连接成功
      if (mounted) {
        Navigator.pop(context);
        
        _bluetoothGlobalState.setBluetoothConnected(true, device, device.name.isEmpty ? '未知设备' : device.name);
        
        // 显示连接成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已成功连接衣物设备 ${device.name}！')),
        );
        
        // 显示已连接设备板块，包含校准提示
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.wifi_tethering, color: Color(0xFF4A90E2)),
                SizedBox(width: 8),
                Text('已连接设备'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('已成功连接衣物设备 ${device.name}！'),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.accessibility, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('校准提示'),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('请在成功连接衣服裤子两个设备后前往模型展示页面校准'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _searchBluetoothDevices();
                },
                child: const Text('继续连接设备'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      print('连接设备时出错: $error');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接设备失败: $error')),
        );
      }
    }
  }

  // 开始校准
  void _startCalibration() {
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
        // 发送校准成功的数据到后端
        _sendBluetoothData();
        // 返回到主页面并切换到模型展示选项卡
        Navigator.pushNamed(context, '/main', arguments: {'tabIndex': 2});
      }
    });
  }

  // 发送蓝牙数据到后端
  Future<void> _sendBluetoothData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      
      if (userId == null) {
        print('用户未登录，无法发送蓝牙数据');
        return;
      }
      
      // 模拟蓝牙设备发送的姿态数据
      final bluetoothData = {
        'user_id': userId,
        'device_id': _bluetoothGlobalState.deviceName,
        'timestamp': DateTime.now().toIso8601String(),
        'posture_data': {
          'quaternion': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
          'euler': {'roll': 0.0, 'pitch': 0.0, 'yaw': 0.0},
          'linear_acceleration': {'x': 0.0, 'y': 0.0, 'z': 9.8}
        },
        'battery_level': 85,
        'signal_strength': 90
      };
      
      final response = await http.post(
        Uri.parse(ApiConfig.bluetoothUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bluetoothData),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('蓝牙数据发送成功');
      } else {
        print('蓝牙数据发送失败: ${response.statusCode}');
      }
    } catch (error) {
      print('发送蓝牙数据时出错: $error');
    }
  }

  // 修改手机号对话框
  void _showChangePhoneDialog() async {
    await _fetchUserInfo();
    
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改手机号'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text('原手机号：$_phone'),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: '新手机号',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: '验证码',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    // 发送验证码到邮箱
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('验证码已发送到您的邮箱')),
                    );
                  },
                  child: const Text('获取验证码'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newPhone = phoneController.text.trim();
              final code = codeController.text.trim();
              
              if (newPhone.isEmpty || code.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请填写完整信息')),
                );
                return;
              }
              
              // 验证验证码逻辑
              setState(() {
                _phone = newPhone;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('手机号修改成功')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 修改邮箱对话框
  void _showChangeEmailDialog() async {
    await _fetchUserInfo();
    
    final TextEditingController oldCodeController = TextEditingController();
    final TextEditingController newEmailController = TextEditingController();
    final TextEditingController newCodeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改邮箱'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('第一步：验证原邮箱'),
            const SizedBox(height: 8),
            Text('原邮箱：$_email'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: oldCodeController,
                    decoration: const InputDecoration(
                      labelText: '验证码',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    // 发送验证码到原邮箱
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('验证码已发送到原邮箱')),
                    );
                  },
                  child: const Text('获取验证码'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('第二步：设置新邮箱'),
            TextField(
              controller: newEmailController,
              decoration: const InputDecoration(
                labelText: '新邮箱',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: newCodeController,
                    decoration: const InputDecoration(
                      labelText: '验证码',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    final newEmail = newEmailController.text.trim();
                    if (newEmail.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入新邮箱')),
                      );
                      return;
                    }
                    // 发送验证码到新邮箱
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('验证码已发送到新邮箱')),
                    );
                  },
                  child: const Text('获取验证码'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final oldCode = oldCodeController.text.trim();
              final newEmail = newEmailController.text.trim();
              final newCode = newCodeController.text.trim();
              
              if (oldCode.isEmpty || newEmail.isEmpty || newCode.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请填写完整信息')),
                );
                return;
              }
              
              // 更新到后端
              await _updateUserInfo({'email': newEmail});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('邮箱修改成功')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 修改密码对话框
  void _showChangePasswordDialog() {
    final TextEditingController oldPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              decoration: const InputDecoration(
                labelText: '原密码',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(
                labelText: '新密码',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                labelText: '确认新密码',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final oldPassword = oldPasswordController.text.trim();
              final newPassword = newPasswordController.text.trim();
              final confirmPassword = confirmPasswordController.text.trim();
              
              if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请填写完整信息')),
                );
                return;
              }
              
              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('两次输入的密码不一致')),
                );
                return;
              }
              
              // 更新到后端
              await _updateUserInfo({'password': newPassword});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('密码修改成功')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  // 修改身份对话框
  void _showChangeIdentityDialog() async {
    await _fetchUserInfo();
    
    final TextEditingController identityController = TextEditingController(text: _identity);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改身份'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: identityController,
              decoration: const InputDecoration(
                labelText: '身份',
                border: OutlineInputBorder(),
                hintText: '可选，默认为"默认"',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newIdentity = identityController.text.trim();
              
              // 更新到后端
              await _updateUserInfo({'identity': newIdentity.isEmpty ? '默认' : newIdentity});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('身份修改成功')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  // 修改疾病史对话框
  void _showChangeIllsDialog() async {
    await _fetchUserInfo();
    
    final TextEditingController illsController = TextEditingController(text: _ills);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改疾病史'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: illsController,
              decoration: const InputDecoration(
                labelText: '疾病史',
                border: OutlineInputBorder(),
                hintText: '可选，默认为"无"',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newIlls = illsController.text.trim();
              
              // 更新到后端
              await _updateUserInfo({'ills': newIlls.isEmpty ? '无' : newIlls});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('疾病史修改成功')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 修改年龄对话框
  void _showChangeAgeDialog() async {
    await _fetchUserInfo();
    
    final TextEditingController ageController = TextEditingController(text: _age.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改年龄'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ageController,
              decoration: const InputDecoration(
                labelText: '年龄',
                border: OutlineInputBorder(),
                hintText: '请输入您的年龄',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final ageText = ageController.text.trim();
              
              if (ageText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入年龄')),
                );
                return;
              }
              
              final newAge = int.tryParse(ageText);
              if (newAge == null || newAge < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的年龄')),
                );
                return;
              }
              
              // 更新到后端
              await _updateUserInfo({'age': newAge});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('年龄修改成功')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 修改身高对话框
  void _showChangeHeightDialog() async {
    await _fetchUserInfo();
    
    final TextEditingController heightController = TextEditingController(text: _height > 0 ? _height.toString() : '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改身高'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: heightController,
              decoration: const InputDecoration(
                labelText: '身高',
                border: OutlineInputBorder(),
                hintText: '请输入您的身高（cm）',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final heightText = heightController.text.trim();
              
              if (heightText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入身高')),
                );
                return;
              }
              
              final newHeight = double.tryParse(heightText);
              if (newHeight == null || newHeight <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的身高')),
                );
                return;
              }
              
              // 更新到后端
              await _updateUserInfo({'height': newHeight});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('身高修改成功')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 修改体重对话框
  void _showChangeWeightDialog() async {
    await _fetchUserInfo();
    
    final TextEditingController weightController = TextEditingController(text: _weight > 0 ? _weight.toString() : '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改体重'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              decoration: const InputDecoration(
                labelText: '体重',
                border: OutlineInputBorder(),
                hintText: '请输入您的体重（kg）',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final weightText = weightController.text.trim();
              
              if (weightText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入体重')),
                );
                return;
              }
              
              final newWeight = double.tryParse(weightText);
              if (newWeight == null || newWeight <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的体重')),
                );
                return;
              }
              
              // 更新到后端
              await _updateUserInfo({'weight': newWeight});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('体重修改成功')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 检查是否需要自动增加年龄
  void _checkAndUpdateAge() {
    // 这里可以实现每年自动增加一岁的逻辑
    // 例如：存储用户的生日，然后根据当前日期计算年龄
    // 由于这是模拟环境，我们暂时不实现具体的自动增加逻辑
    // 实际应用中，应该在应用启动时检查并更新年龄
  }

  // 从本地存储中读取用户信息
  Future<void> _loadUserInfoFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final userIdentifier = prefs.getString('userIdentifier');
    final userId = prefs.getInt('userId');
    final isLoggedIn = prefs.getBool('isLoggedIn');
    
    print('=== 读取本地存储信息 ===');
    print('isLoggedIn: $isLoggedIn');
    print('userIdentifier: $userIdentifier');
    print('userId: $userId');
    
    if (mounted) {
      setState(() {
        if (userIdentifier != null) {
          _phone = userIdentifier;
        }
        _userId = userId;
      });
    }
    
    try {
      final userInfoJson = prefs.getString('user_info');
      if (userInfoJson != null) {
        final userInfo = jsonDecode(userInfoJson);
        print('从本地存储读取到用户信息: $userInfo');
        
        if (mounted) {
          setState(() {
            _email = userInfo['email'] ?? '';
            _age = userInfo['age'] ?? 0;
            _height = userInfo['height'] ?? 0.0;
            _weight = userInfo['weight'] ?? 0.0;
            _identity = userInfo['identity'] ?? '';
            _ills = userInfo['ills'] ?? '';
            _isDataLoaded = true;
          });
        }
      }
    } catch (e) {
      print('从本地存储读取用户信息失败: $e');
    }
  }

  // 保存用户信息到本地存储
  Future<void> _saveUserInfoToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userInfo = {
        'phone': _phone,
        'email': _email,
        'age': _age,
        'height': _height,
        'weight': _weight,
        'identity': _identity,
        'ills': _ills,
      };
      final userInfoJson = jsonEncode(userInfo);
      await prefs.setString('user_info', userInfoJson);
      print('用户信息已保存到本地存储');
    } catch (e) {
      print('保存用户信息到本地存储失败: $e');
    }
  }

  // 从后端获取用户详细信息
  Future<void> _fetchUserInfo() async {
    if (_userId == null) {
      await _loadUserInfoFromStorage();
      if (_userId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isDataLoaded = false;
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _isDataLoaded = false;
      });
    }

    try {
      print('=== 开始获取用户信息 ===');
      print('请求URL: ${ApiConfig.baseUrl}/posture/info/');
      print('请求参数: user_id = $_userId');
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/posture/info/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _userId}),
      );

      print('响应状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('解析后的数据: $data');
        print('status字段: ${data['status']}');
        
        if (data['status'] == 'success') {
            if (mounted) {
              setState(() {
                _phone = data['phone'] ?? '';
                _email = data['email'] ?? '';
                _age = data['age'] ?? 0;
                _height = data['height'] ?? 0.0;
                _weight = data['weight'] ?? 0.0;
                _identity = data['identity'] ?? '';
                _ills = data['ills'] ?? '';
                _isDataLoaded = true;
                print('设置_isDataLoaded为true');
              });
              // 保存用户信息到本地存储
              await _saveUserInfoToStorage();
              // 启动动画
              _animationController.forward();
            }
          } else {
          print('后端返回失败: ${data['status']}');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isDataLoaded = false;
            });
          }
        }
      } else {
        print('HTTP请求失败: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isDataLoaded = false;
          });
        }
      }
    } catch (e) {
      print('获取用户信息失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDataLoaded = false;
        });
      }
    } finally {
      // 无论成功失败，都要将_isLoading设置为false
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    print('=== 获取用户信息完成 ===');
    print('_isLoading: $_isLoading');
    print('_isDataLoaded: $_isDataLoaded');
    print('_userId: $_userId');
    print('_phone: $_phone');
    print('_email: $_email');
    print('_age: $_age');
    print('_height: $_height');
    print('_weight: $_weight');
    print('_identity: $_identity');
    print('_ills: $_ills');
  }

  // 更新用户信息到后端
  Future<void> _updateUserInfo(Map<String, dynamic> updates) async {
    if (_userId == null) {
      await _loadUserInfoFromStorage();
      if (_userId == null) return;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/posture/update/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _userId, ...updates}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && mounted) {
          // 更新成功，刷新本地数据
          await _fetchUserInfo();
        }
      }
    } catch (e) {
      print('更新用户信息失败: $e');
    }
  }

  // 刷新用户信息
  Future<void> _refreshUserInfo() async {
    await _loadUserInfoFromStorage();
    await _fetchUserInfo();
  }

  // 移除didChangeDependencies中的刷新，避免重复请求
}