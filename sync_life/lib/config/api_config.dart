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
  
  // 身体运动数据接口
  static const String bodyMovementUrl = '$baseUrl/posture/body-movement/';
}  