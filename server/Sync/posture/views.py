from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
import json
import requests
from django.utils import timezone
from .models import User, PostureRecord, State, AgeGroup, PostureRiskLevel
import subprocess
import os
import signal
import psutil

class StableAngleCalculator:
    def __init__(self, window_size=15, variance_threshold=1.5):
        self.window_size = window_size
        self.variance_threshold = variance_threshold
        self.angles = []
        self.mean = 0.0
        self.variance = 0.0

    def add_angle(self, angle):
        if len(self.angles) >= self.window_size:
            old_angle = self.angles.pop(0)
            old_mean = self.mean
            self.mean = old_mean + (angle - old_angle) / self.window_size
            self.variance = self.variance + (angle - self.mean) * (angle - old_mean) / (self.window_size - 1)
        else:
            old_mean = self.mean
            self.mean = (old_mean * len(self.angles) + angle) / (len(self.angles) + 1)
            if len(self.angles) > 0:
                self.variance = (self.variance * (len(self.angles) - 1) + (angle - old_mean) * (angle - self.mean)) / len(self.angles)
        self.angles.append(angle)

    def get_stable_angle(self):
        if len(self.angles) >= self.window_size and self.variance <= self.variance_threshold:
            return self.mean
        return None

    def reset(self):
        self.angles = []
        self.mean = 0.0
        self.variance = 0.0

calculators = {}

angle_standards = {
    AgeGroup.YOUTH.value: {
        State.LIE.value: {"trunk": (0, 3)},
        State.STAND.value: {"trunk": (0, 2)},
        State.SIT.value: {"trunk": (0, 5)},
        State.WALK.value: {"trunk": (3, 8)},
        State.RUN.value: {"trunk": (8, 12)},
    },
    AgeGroup.PRIME.value: {
        State.LIE.value: {"trunk": (0, 3)},
        State.STAND.value: {"trunk": (0, 2)},
        State.SIT.value: {"trunk": (0, 5)},
        State.WALK.value: {"trunk": (3, 8)},
        State.RUN.value: {"trunk": (8, 12)},
    },
    AgeGroup.MIDDLE.value: {
        State.LIE.value: {"trunk": (0, 5)},
        State.STAND.value: {"trunk": (0, 3)},
        State.SIT.value: {"trunk": (0, 8)},
        State.WALK.value: {"trunk": (5, 10)},
        State.RUN.value: {"trunk": (10, 15)},
    },
    AgeGroup.SENIOR.value: {
        State.LIE.value: {"trunk": (0, 5)},
        State.STAND.value: {"trunk": (0, 4)},
        State.SIT.value: {"trunk": (0, 10)},
        State.WALK.value: {"trunk": (8, 12)},
        State.RUN.value: {"trunk": (12, 15)},
    },
}

def get_risk_level(angle, standard_range, age_group, ills):
    mid_point = (standard_range[0] + standard_range[1]) / 2
    deviation = abs(angle - mid_point)
    
    if standard_range[0] <= angle <= standard_range[1]:
        return PostureRiskLevel.NORMAL.value
    
    if age_group == AgeGroup.SENIOR.value and not ills:
        if deviation <= 12:
            return PostureRiskLevel.MILD_RISK.value
        else:
            return PostureRiskLevel.SEVERE_RISK.value
    else:
        if deviation <= 10:
            return PostureRiskLevel.MILD_RISK.value
        else:
            return PostureRiskLevel.SEVERE_RISK.value

@csrf_exempt
def process_posture_data(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user_id = data.get('user_id')
            timestamp = data.get('timestamp')
            raw_data = data.get('raw_data')
            
            if not user_id or not timestamp or not raw_data:
                return JsonResponse({'error': 'Missing required fields'}, status=400)
            
            try:
                user = User.objects.get(id=user_id)
            except User.DoesNotExist:
                return JsonResponse({'error': 'User not found'}, status=404)
            
            trunk_angle = raw_data.get('trunk_angle')
            
            if trunk_angle is None:
                return JsonResponse({'error': 'Missing trunk angle data'}, status=400)
            
            if trunk_angle <= -10 or trunk_angle >= 40:
                return JsonResponse({'error': 'Trunk angle out of range'}, status=400)
            
            state = raw_data.get('state', State.STAND.value)
            
            if user_id not in calculators:
                window_size = 20 if user.age_group == AgeGroup.SENIOR.value else 15
                variance_threshold = 2.5 if user.age_group == AgeGroup.SENIOR.value else 1.5
                calculators[user_id] = {
                    'trunk': StableAngleCalculator(window_size, variance_threshold),
                    'last_state': state
                }
            
            if calculators[user_id]['last_state'] != state:
                calculators[user_id]['trunk'].reset()
                calculators[user_id]['last_state'] = state
            
            calculators[user_id]['trunk'].add_angle(trunk_angle)
            
            trunk_stable = calculators[user_id]['trunk'].get_stable_angle()
            
            if not trunk_stable:
                return JsonResponse({'status': 'calculating'})
            
            trunk_standard = angle_standards[user.age_group][state]['trunk']
            
            risk_level = get_risk_level(trunk_stable, trunk_standard, user.age_group, user.ills)
            
            last_record = PostureRecord.objects.filter(user=user, end_time__isnull=True).order_by('-start_time').first()
            
            if last_record:
                if last_record.state != state or last_record.posture_risk_level != risk_level:
                    last_record.end_time = timezone.now()
                    last_record.save()
                    
                    new_record = PostureRecord(
                        user=user,
                        state=state,
                        trunk_stable_angle=trunk_stable,
                        posture_risk_level=risk_level
                    )
                    new_record.save()
            else:
                new_record = PostureRecord(
                    user=user,
                    state=state,
                    trunk_stable_angle=trunk_stable,
                    posture_risk_level=risk_level
                )
                new_record.save()
            
            return JsonResponse({
                'status': 'success',
                'user_id': user_id,
                'state': state,
                'trunk_stable_angle': trunk_stable,
                'posture_risk_level': risk_level,
                'age_group': user.age_group
            })
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON'}, status=400)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
    else:
        return JsonResponse({'error': 'Method not allowed'}, status=405)


@csrf_exempt
def start_bluetooth_receiver(request):
    """
    启动蓝牙接收脚本
    """
    if request.method == 'POST':
        try:
            # 停止已有的脚本实例
            # 查找所有运行 bluetooth_receiver.py 的进程
            for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
                try:
                    if proc.info['cmdline'] and 'bluetooth_receiver.py' in ' '.join(proc.info['cmdline']):
                        print(f"停止已有进程: {proc.info['pid']}")
                        proc.terminate()
                        proc.wait(timeout=5)
                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                    pass
            
            # 启动新的脚本实例
            script_path = os.path.join(os.path.dirname(__file__), '..', 'bluetooth_receiver.py')
            print(f"启动脚本: {script_path}")
            
            # 使用 Popen 启动脚本，设置 cwd 为脚本所在目录
            cwd = os.path.dirname(script_path)
            process = subprocess.Popen(['python', 'bluetooth_receiver.py'], cwd=cwd)
            
            return JsonResponse({'status': 'success', 'message': '蓝牙接收脚本已启动', 'pid': process.pid})
        except Exception as e:
            print(f"启动脚本异常: {str(e)}")
            return JsonResponse({'error': str(e)}, status=500)
    return JsonResponse({'error': 'Invalid request method'}, status=405)

def home(request):
    return JsonResponse({
        'status': 'success',
        'message': 'Posture Monitoring API',
        'endpoints': {
            'send_code': '/api/posture/send-code/',
            'register': '/api/posture/register/',
            'login': '/api/posture/login/',
            'process_posture': '/api/posture/process/'
        },
        'documentation': 'POST requests only'
    })

import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import random
import string
from django.utils import timezone
import threading

# 存储验证码的字典，格式: {email: (code, expiry_time)}
verification_codes = {}

def send_email_verification(email, code):
    """发送邮箱验证码"""
    try:
        # 这里使用模拟发送，实际部署时需要配置真实的SMTP服务器
        print(f"向 {email} 发送验证码: {code}")
        # 实际发送代码示例（需要配置SMTP服务器）:
        # msg = MIMEMultipart()
        # msg['From'] = 'your-email@example.com'
        # msg['To'] = email
        # msg['Subject'] = '注册验证码'
        # body = f'您的注册验证码是: {code}，有效期5分钟'
        # msg.attach(MIMEText(body, 'plain'))
        # server = smtplib.SMTP('smtp.example.com', 587)
        # server.starttls()
        # server.login('your-email@example.com', 'your-password')
        # text = msg.as_string()
        # server.sendmail('your-email@example.com', email, text)
        # server.quit()
    except Exception as e:
        print(f"发送邮件失败: {str(e)}")

@csrf_exempt
def send_verification_code(request):
    """发送验证码API"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            email = data.get('email')
            
            if not email:
                return JsonResponse({'error': 'Missing email'}, status=400)
            
            # 生成6位随机验证码
            code = ''.join(random.choices(string.digits, k=6))
            expiry_time = timezone.now() + timezone.timedelta(minutes=5)
            
            # 存储验证码
            verification_codes[email] = (code, expiry_time)
            
            # 异步发送验证码
            threading.Thread(target=send_email_verification, args=(email, code)).start()
            
            return JsonResponse({
                'status': 'success',
                'message': '验证码已发送到您的邮箱',
                'email': email
            })
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON'}, status=400)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
    else:
        return JsonResponse({'error': 'Method not allowed'}, status=405)

@csrf_exempt
def register(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            phone = data.get('phone')
            email = data.get('email')
            password = data.get('password')
            verification_code = data.get('verification_code')
            identity = data.get('identity')
            age = data.get('age')
            weight = data.get('weight')
            height = data.get('height')
            ills = data.get('ills')
            
            if not phone or not email or not password or not verification_code or not age or not weight or not height:
                return JsonResponse({'error': 'Missing required fields'}, status=400)
            
            # 验证验证码
            if email not in verification_codes:
                return JsonResponse({'error': '验证码已过期或不存在'}, status=400)
            
            code, expiry_time = verification_codes[email]
            if timezone.now() > expiry_time:
                del verification_codes[email]
                return JsonResponse({'error': '验证码已过期'}, status=400)
            
            if code != verification_code:
                return JsonResponse({'error': '验证码错误'}, status=400)
            
            # 验证码验证通过，删除验证码
            del verification_codes[email]
            
            # 检查手机号和邮箱是否已注册
            if User.objects.filter(phone=phone).exists():
                return JsonResponse({'error': 'Phone number already registered'}, status=400)
            
            if User.objects.filter(email=email).exists():
                return JsonResponse({'error': 'Email already registered'}, status=400)
            
            user = User(
                phone=phone,
                email=email,
                identity=identity,
                age=age,
                weight=weight,
                height=height,
                ills=ills
            )
            user.set_password(password)
            user.save()
            
            return JsonResponse({
                'status': 'success',
                'user_id': user.id,
                'age_group': user.age_group,
                'message': 'Registration successful'
            })
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON'}, status=400)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
    else:
        return JsonResponse({'error': 'Method not allowed'}, status=405)

@csrf_exempt
def login(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            identifier = data.get('identifier')  # 手机号或邮箱
            password = data.get('password')
            
            if not identifier or not password:
                return JsonResponse({'error': 'Missing required fields'}, status=400)
            
            # 尝试通过手机号查找用户
            try:
                user = User.objects.get(phone=identifier)
            except User.DoesNotExist:
                # 尝试通过邮箱查找用户
                try:
                    user = User.objects.get(email=identifier)
                except User.DoesNotExist:
                    return JsonResponse({'error': 'User not found'}, status=404)
            
            if not user.check_password(password):
                return JsonResponse({'error': 'Invalid password'}, status=401)
            
            return JsonResponse({
                'status': 'success',
                'user_id': user.id,
                'phone': user.phone,
                'email': user.email,
                'age': user.age,
                'identity': user.identity,
                'ills': user.ills,
                'age_group': user.age_group,
                'message': 'Login successful'
            })
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON'}, status=400)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
    else:
        return JsonResponse({'error': 'Method not allowed'}, status=405)

@csrf_exempt
def update_user_info(request):
    """更新用户信息API"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user_id = data.get('user_id')
            phone = data.get('phone')
            email = data.get('email')
            age = data.get('age')
            height = data.get('height')
            weight = data.get('weight')
            identity = data.get('identity')
            ills = data.get('ills')
            password = data.get('password')
            
            if not user_id:
                return JsonResponse({'error': 'Missing user_id'}, status=400)
            
            try:
                user = User.objects.get(id=user_id)
            except User.DoesNotExist:
                return JsonResponse({'error': 'User not found'}, status=404)
            
            # 更新用户信息
            if phone:
                user.phone = phone
            if email:
                user.email = email
            if age is not None:
                user.age = age
            if height is not None:
                user.height = height
            if weight is not None:
                user.weight = weight
            if identity is not None:
                user.identity = identity
            if ills is not None:
                user.ills = ills
            if password:
                user.set_password(password)
            
            user.save()
            
            return JsonResponse({
                'status': 'success',
                'user_id': user.id,
                'phone': user.phone,
                'email': user.email,
                'age': user.age,
                'height': user.height,
                'weight': user.weight,
                'identity': user.identity,
                'ills': user.ills,
                'age_group': user.age_group,
                'message': 'User info updated successfully'
            })
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON'}, status=400)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
    else:
        return JsonResponse({'error': 'Method not allowed'}, status=405)

@csrf_exempt
def get_user_info(request):
    """获取用户信息API"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user_id = data.get('user_id')
            
            if not user_id:
                return JsonResponse({'error': 'Missing user_id'}, status=400)
            
            try:
                user = User.objects.get(id=user_id)
            except User.DoesNotExist:
                return JsonResponse({'error': 'User not found'}, status=404)
            
            return JsonResponse({
                'status': 'success',
                'user_id': user.id,
                'phone': user.phone,
                'email': user.email,
                'age': user.age,
                'height': user.height,
                'weight': user.weight,
                'identity': user.identity,
                'ills': user.ills,
                'age_group': user.age_group,
                'message': 'User info retrieved successfully'
            })
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON'}, status=400)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
    else:
        return JsonResponse({'error': 'Method not allowed'}, status=405)

@csrf_exempt
def process_with_n8n(request):
    """调用N8N工作流处理消息API"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user_id = data.get('user_id')
            message = data.get('message')
            session_id = data.get('session_id')
            type = data.get('type', 'text')
            
            if not user_id or not message:
                return JsonResponse({'error': 'Missing required fields'}, status=400)
            
            # 准备发送给N8N的数据
            n8n_data = {
                'user_id': user_id,
                'message': message,
                'session_id': session_id,
                'type': type
            }
            
            # 调用N8N工作流
            try:
                print(f"调用N8N工作流，数据: {n8n_data}")
                response = requests.post(
                    'http://localhost:5678/webhook-test/9e6006dc-95aa-40f3-ba3e-5db8cb5404c8',
                    json=n8n_data,
                    timeout=200
                )
                
                print(f"N8N响应状态码: {response.status_code}")
                print(f"N8N响应内容: {response.text}")
                
                if response.status_code == 200:
                    return JsonResponse(response.json())
                else:
                    return JsonResponse({'error': 'N8N request failed', 'status_code': response.status_code}, status=500)
                    
            except Exception as e:
                print(f"N8N调用异常: {str(e)}")
                # 检查是否是webhook未注册的错误
                if "is not registered" in str(e) or "404" in str(e):
                    return JsonResponse({'error': 'N8N工作流未激活，请在N8N界面上点击"Execute workflow"按钮后重试'}, status=400)
                return JsonResponse({'error': str(e)}, status=500)
                
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON'}, status=400)
        except Exception as e:
            print(f"处理异常: {str(e)}")
            return JsonResponse({'error': str(e)}, status=500)
    else:
        return JsonResponse({'error': 'Method not allowed'}, status=405)

@csrf_exempt
def process_clothing_data(request):
    """处理智能服装传感器数据API"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user_id = data.get('user_id')
            sensor_data = data.get('sensor_data')  # 11个传感器数据
            
            if not user_id or not sensor_data:
                return JsonResponse({'error': 'Missing required fields'}, status=400)
            
            # 处理智能服装数据
            print(f"接收到智能服装数据，用户ID: {user_id}")
            print(f"传感器数据长度: {len(sensor_data)}")
            
            # 1. 数据预处理
            # 2. 姿态估计
            # 3. 运动状态识别
            
            return JsonResponse({
                'status': 'success',
                'user_id': user_id,
                'message': '智能服装数据处理成功'
            })
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON'}, status=400)
        except Exception as e:
            print(f"处理智能服装数据异常: {str(e)}")
            return JsonResponse({'error': str(e)}, status=500)
    else:
        return JsonResponse({'error': 'Method not allowed'}, status=405)

# 添加 Human+clothes 到 Python 路径
import sys
sys.path.append('D:\Sync-Life\server\Human+clothes')
import numpy as np

# 尝试导入 onnxruntime，如果不可用则使用替代方案
try:
    import onnxruntime as rt
    ONNXRUNTIME_AVAILABLE = True
except ImportError:
    rt = None
    ONNXRUNTIME_AVAILABLE = False

# 尝试导入 Human+clothes 相关模块
try:
    import config
    from hardware_boot.receive_bleak_085 import data_up_buffer, data_down_buffer
    from Aplus.tools.pd_controll import FpsController
    from Socket.UDP import DataProcessServer_FullBody
    from Socket.UDP import demo_mode
    HUMAN_CLOTHES_AVAILABLE = True
except ImportError:
    config = None
    data_up_buffer = None
    data_down_buffer = None
    FpsController = None
    DataProcessServer_FullBody = None
    demo_mode = None
    HUMAN_CLOTHES_AVAILABLE = False

# 全局变量
i_session = None
calibration_session = None
my_server = None
imu_order_clothes = None
imu_order_pant = None
CALIBRATION_DONE = False

# 运动姿态分类器类
class MotionClassifier:
    def __init__(self, buffer_len=20):
        # 用于存储最近N帧的加速度幅值，用于计算方差（判断运动剧烈程度）
        self.acc_mag_buffer = []
        
        # 存储校准时的参考重力向量 (Stand状态)
        self.ref_gravity_upper = None # 上身平均重力向量
        self.ref_gravity_lower = None # 下身平均重力向量
        
        # 状态机平滑（防止状态闪烁）
        self.current_display_state = "初始化"

    def set_calibration_ref(self, data_upper, data_lower):
        """
        在T-Pose校准时调用，记录站立时的重力方向
        data_upper: (6, 3) 加速度
        data_lower: (5, 3) 加速度
        """
        # 计算平均加速度向量作为重力参考方向
        self.ref_gravity_upper = np.mean(data_upper, axis=0)
        self.ref_gravity_lower = np.mean(data_lower, axis=0)
        # 归一化
        self.ref_gravity_upper /= np.linalg.norm(self.ref_gravity_upper)
        self.ref_gravity_lower /= np.linalg.norm(self.ref_gravity_lower)
        print("\n[运动识别] 姿态基准已校准 (Stand Reference Set)")

    def get_angle(self, v1, v2):
        """计算两个向量的夹角(度)"""
        v1_n = v1 / (np.linalg.norm(v1) + 1e-6)
        v2_n = v2 / (np.linalg.norm(v2) + 1e-6)
        dot = np.clip(np.dot(v1_n, v2_n), -1.0, 1.0)
        return np.degrees(np.arccos(dot))

    def update(self, full_data):
        """
        full_data: (11, 7) [acc x3, quat x4]
        返回: 状态字符串
        """
        if self.ref_gravity_upper is None:
            return "等待校准"

        # 分离上身(前6个)和下身(后5个)数据
        # 注意：这里取加速度的前3列
        acc_data = full_data[:, 0:3]
        acc_upper = acc_data[:6]
        acc_lower = acc_data[6:]

        # 1. --- 动静判断 (Walk/Run vs Static) ---
        # 计算全身平均加速度的模长
        avg_acc_mag = np.mean(np.linalg.norm(acc_data, axis=1))
        self.acc_mag_buffer.append(avg_acc_mag)
        if len(self.acc_mag_buffer) > 20:
            self.acc_mag_buffer.pop(0)
        
        # 计算方差 (方差越大，动作越剧烈)
        variance = np.var(self.acc_mag_buffer) if len(self.acc_mag_buffer) > 5 else 0
        
        # 阈值需要根据实际传感器灵敏度调整，以下为经验值
        RUN_THRESH = 15.0  
        WALK_THRESH = 1.5   
        
        motion_state = "STATIC"
        if variance > RUN_THRESH:
            motion_state = "RUN"
        elif variance > WALK_THRESH:
            motion_state = "WALK"

        # 2. --- 姿态判断 (Stand/Sit/Lie) ---
        # 仅当处于静态或微动时判断具体姿态
        pose_state = "STAND"
        if motion_state == "STATIC" or motion_state == "WALK":
            # 获取当前平均重力向量
            curr_grav_upper = np.mean(acc_upper, axis=0)
            curr_grav_lower = np.mean(acc_lower, axis=0)
            
            # 计算与校准态(站立)的偏差角度
            angle_upper = self.get_angle(curr_grav_upper, self.ref_gravity_upper)
            angle_lower = self.get_angle(curr_grav_lower, self.ref_gravity_lower)

            # 判定逻辑
            # 躺：上身大幅度倾斜 (比如 > 50度)
            if angle_upper > 50:
                pose_state = "LIE"
            # 坐：上身直立 (< 40度) 且 下身大幅度倾斜 (> 50度)
            elif angle_upper < 40 and angle_lower > 50:
                pose_state = "SIT"
            else:
                pose_state = "STAND"
        
        # 3. --- 综合输出 ---
        final_state = pose_state
        if motion_state == "RUN":
            final_state = "RUN (跑步)"
        elif motion_state == "WALK" and pose_state == "STAND":
            final_state = "WALK (慢走)"
        elif pose_state == "SIT":
            final_state = "SIT (坐)"
        elif pose_state == "LIE":
            final_state = "LIE (躺)"
        else:
            final_state = "STAND (站立)"

        # 简单滤波输出
        self.current_display_state = final_state
        return final_state

# 实例化分类器
motion_recognizer = MotionClassifier()

# 初始化 Human+clothes 算法
def init_human_clothes():
    global i_session, calibration_session, my_server, imu_order_clothes, imu_order_pant
    try:
        # 检查必要的模块是否可用
        if not ONNXRUNTIME_AVAILABLE:
            print('[Human+clothes] 算法初始化失败: onnxruntime 模块不可用')
            return
        
        if not HUMAN_CLOTHES_AVAILABLE:
            print('[Human+clothes] 算法初始化失败: Human+clothes 模块不可用')
            return
        
        # 加载 ONNX 模型
        providers = ['CPUExecutionProvider']
        i_session = rt.InferenceSession('D:\Sync-Life\server\Human+clothes\onnx_models\LFP_dense_taichi_ft.onnx', providers=providers)
        calibration_session = rt.InferenceSession('D:\Sync-Life\server\Human+clothes\onnx_models\TIC4Clothes_dense.onnx', providers=providers)

        # 加载设备配置
        device_config_clothes = config.device_config.jacket_6IMU
        imu_order_clothes = device_config_clothes['imu_order']

        device_config_pant = config.device_config.pants_5IMU
        imu_order_pant = device_config_pant['imu_order']

        # 初始化数据处理服务器
        from Socket.UDP import DataProcessServer_FullBody
        from Socket.UDP import demo_mode
        my_server = DataProcessServer_FullBody(
            rotation_type='AXIS_ANGLE', 
            part='body',
            config=[device_config_clothes, device_config_pant], 
            mode=demo_mode.FULL,
            track_trans=False,
            calibration_session=calibration_session, 
            run_unity_package=False,
            physics_optim=True,
            cali_pose='T', 
            beta=None
        )
        print('[Human+clothes] 算法初始化完成')
    except Exception as e:
        print(f'[Human+clothes] 算法初始化失败: {str(e)}')

# 初始化 Human+clothes 算法
init_human_clothes()

def quaternion_to_rotation_matrix(quaternions):
    """将四元数转换为旋转矩阵"""
    if isinstance(quaternions, list):
        quaternions = np.array(quaternions)
    
    w, x, y, z = quaternions[..., 0], quaternions[..., 1], quaternions[..., 2], quaternions[..., 3]
    
    # 计算旋转矩阵
    shape = quaternions.shape[:-1] + (3, 3)
    rot_mat = np.zeros(shape)
    rot_mat[..., 0, 0] = 1 - 2 * (y**2 + z**2)
    rot_mat[..., 0, 1] = 2 * (x * y - w * z)
    rot_mat[..., 0, 2] = 2 * (x * z + w * y)
    
    rot_mat[..., 1, 0] = 2 * (x * y + w * z)
    rot_mat[..., 1, 1] = 1 - 2 * (x**2 + z**2)
    rot_mat[..., 1, 2] = 2 * (y * z - w * x)
    
    rot_mat[..., 2, 0] = 2 * (x * z - w * y)
    rot_mat[..., 2, 1] = 2 * (y * z + w * x)
    rot_mat[..., 2, 2] = 1 - 2 * (x**2 + y**2)
    
    return rot_mat

@csrf_exempt
def process_bluetooth_data(request):
    """处理蓝牙设备姿态数据API"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user_id = data.get('user_id')
            raw_data = data.get('raw_data')
            
            if not user_id:
                return JsonResponse({'error': 'Missing required fields'}, status=400)
            
            # 如果 raw_data 为空，使用默认值
            if not raw_data:
                raw_data = []
            
            try:
                user = User.objects.get(id=user_id)
            except User.DoesNotExist:
                return JsonResponse({'error': 'User not found'}, status=404)
            
            # 处理原始蓝牙数据，计算姿态角
            pitch = 0.0
            roll = 0.0
            yaw = 0.0
            state = 1  # 默认状态为站立 (STAND)
            risk_level = 'NORMAL'  # 默认风险等级为正常 (NORMAL)
            
            # 尝试解析原始蓝牙数据并调用 Human+clothes 算法
            try:
                # 检查数据头部
                if len(raw_data) >= 4 and raw_data[0] == 255 and raw_data[1] == 254:
                    # 提取长度和时间戳
                    len_data = (raw_data[2] << 8) | raw_data[3]
                    timestamp = (raw_data[4] << 24) | (raw_data[5] << 16) | (raw_data[6] << 8) | raw_data[7]
                    print(f'数据长度: {len_data}, 时间戳: {timestamp}')
                    
                    # 解析IMU数据
                    acc_data = []
                    quat_data = []
                    
                    # 从第8个字节开始解析IMU数据
                    offset = 8
                    for i in range(6):  # 上衣有6个IMU
                        if offset + 24 <= len(raw_data):  # 每个IMU数据占用24字节
                            # 解析加速度数据 (3个float，每个4字节)
                            acc_x = int.from_bytes(raw_data[offset:offset+4], byteorder='little', signed=True) / 1000.0
                            acc_y = int.from_bytes(raw_data[offset+4:offset+8], byteorder='little', signed=True) / 1000.0
                            acc_z = int.from_bytes(raw_data[offset+8:offset+12], byteorder='little', signed=True) / 1000.0
                            
                            # 解析四元数数据 (4个float，每个4字节)
                            quat_w = int.from_bytes(raw_data[offset+12:offset+16], byteorder='little', signed=True) / 10000.0
                            quat_x = int.from_bytes(raw_data[offset+16:offset+20], byteorder='little', signed=True) / 10000.0
                            quat_y = int.from_bytes(raw_data[offset+20:offset+24], byteorder='little', signed=True) / 10000.0
                            quat_z = int.from_bytes(raw_data[offset+24:offset+28], byteorder='little', signed=True) / 10000.0
                            
                            acc_data.extend([acc_x, acc_y, acc_z])
                            quat_data.extend([quat_w, quat_x, quat_y, quat_z])
                            
                            offset += 28
                    
                    # 无论 Human+clothes 算法是否可用，都计算基本的姿态角
                    if acc_data:
                        # 使用第一个IMU的加速度数据计算姿态角
                        acc_x = acc_data[0]
                        acc_y = acc_data[1]
                        acc_z = acc_data[2]
                        
                        # 计算俯仰角 (pitch) 和横滚角 (roll)
                        import math
                        pitch = -math.atan2(acc_x, math.sqrt(acc_y * acc_y + acc_z * acc_z)) * 180 / math.pi
                        roll = math.atan2(acc_y, acc_z) * 180 / math.pi
                        
                        # 假设偏航角 (yaw) 为0
                        yaw = 0.0
                    
                    # 如果有足够的数据且 Human+clothes 算法可用，调用 Human+clothes 算法
                    if len(acc_data) >= 18 and len(quat_data) >= 24 and my_server is not None and ONNXRUNTIME_AVAILABLE and HUMAN_CLOTHES_AVAILABLE:
                        # 构建全身体数据 (11, 7) [acc x3, quat x4]
                        # 这里假设只有上衣数据，裤子数据暂时用默认值
                        data_clothes = np.array(acc_data + quat_data).reshape(6, 7)
                        data_pant = np.zeros((5, 7))  # 裤子数据暂时用默认值
                        data_full_raw = np.concatenate([data_clothes, data_pant], axis=0)
                        
                        # 校准数据
                        accs = data_full_raw[:, 0:3]
                        q = data_full_raw[:, 3:7]
                        oris = quaternion_to_rotation_matrix(q)

                        accs = accs.flatten()
                        oris = oris.flatten()

                        data_list = np.concatenate([accs, oris]).tolist()

                        # 调用 Human+clothes 算法进行姿态估计
                        data_calib = my_server.calibrate(data_list)
                        my_server.operator(data_calib)
                        data_feed = my_server.to_predict_data()
                        
                        # 预测
                        if i_session is not None:
                            result = i_session.run(output_names=None, input_feed=data_feed)
                            result, joint_pos = my_server.predict_result(result)
                            my_server.update_data(result, trans=None)
                            
                            # 从 Human+clothes 算法获取姿态数据
                            # 这里需要根据实际的算法输出格式进行调整
                            # 暂时使用简单的方法计算姿态角
                            if acc_data:
                                # 使用第一个IMU的加速度数据计算姿态角
                                acc_x = acc_data[0]
                                acc_y = acc_data[1]
                                acc_z = acc_data[2]
                                
                                # 计算俯仰角 (pitch) 和横滚角 (roll)
                                import math
                                pitch = -math.atan2(acc_x, math.sqrt(acc_y * acc_y + acc_z * acc_z)) * 180 / math.pi
                                roll = math.atan2(acc_y, acc_z) * 180 / math.pi
                                
                                # 假设偏航角 (yaw) 为0
                                yaw = 0.0
                    
                    # 根据俯仰角判断姿态状态
                    if abs(pitch) < 10:
                        state = 1  # 站立 (STAND)
                    elif pitch > 10:
                        state = 2  # 弯腰 (SIT)
                    else:
                        state = 0  # 后仰 (LIE)
                    
                    # 根据俯仰角判断风险等级
                    if abs(pitch) < 15:
                        risk_level = 'NORMAL'  # 正常
                    elif abs(pitch) < 30:
                        risk_level = 'MILD_RISK'  # 轻度风险
                    else:
                        risk_level = 'SEVERE_RISK'  # 重度风险
                    
                    print(f'解析姿态数据: pitch={pitch}, roll={roll}, yaw={yaw}, state={state}, risk_level={risk_level}')
            except Exception as e:
                print(f'解析原始蓝牙数据异常: {str(e)}')
            
            # 查找最近的未结束的记录
            last_record = PostureRecord.objects.filter(user=user, end_time__isnull=True).order_by('-start_time').first()
            
            # 只有当姿态状态或风险等级发生变化时才存储新记录
            if last_record:
                if last_record.state != state or last_record.posture_risk_level != risk_level:
                    # 结束上一条记录
                    last_record.end_time = timezone.now()
                    last_record.duration = (last_record.end_time - last_record.start_time).total_seconds()
                    last_record.save()
                    
                    # 创建新记录
                    new_record = PostureRecord(
                        user=user,
                        state=state,
                        trunk_stable_angle=abs(pitch),
                        posture_risk_level=risk_level
                    )
                    new_record.save()
            else:
                # 创建第一条记录
                new_record = PostureRecord(
                    user=user,
                    state=state,
                    trunk_stable_angle=abs(pitch),
                    posture_risk_level=risk_level
                )
                new_record.save()
            
            # 转换状态和风险等级为前端可读的格式
            state_map = {
                0: '仰卧',
                1: '站立',
                2: '坐姿',
                3: '行走',
                4: '跑步'
            }
            risk_map = {
                'NORMAL': '正常',
                'MILD_RISK': '轻度风险',
                'SEVERE_RISK': '重度风险'
            }
            
            return JsonResponse({
                'status': 'success',
                'user_id': user_id,
                'posture_data': {
                    'pitch': pitch,
                    'roll': roll,
                    'yaw': yaw,
                    'state': state_map.get(state, '未知'),
                    'risk_level': risk_map.get(risk_level, '未知')
                },
                'message': '蓝牙数据处理成功'
            })
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON'}, status=400)
        except Exception as e:
            print(f"处理蓝牙数据异常: {str(e)}")
            return JsonResponse({'error': str(e)}, status=500)
    elif request.method == 'GET':
        try:
            user_id = request.GET.get('user_id')
            
            if not user_id:
                return JsonResponse({'error': 'Missing user_id'}, status=400)
            
            try:
                user = User.objects.get(id=user_id)
            except User.DoesNotExist:
                return JsonResponse({'error': 'User not found'}, status=404)
            
            # 查找最近的未结束的记录
            last_record = PostureRecord.objects.filter(user=user, end_time__isnull=True).order_by('-start_time').first()
            
            # 转换状态和风险等级为前端可读的格式
            state_map = {
                0: '仰卧',
                1: '站立',
                2: '坐姿',
                3: '行走',
                4: '跑步'
            }
            risk_map = {
                'NORMAL': '正常',
                'MILD_RISK': '轻度风险',
                'SEVERE_RISK': '重度风险'
            }
            
            if last_record:
                return JsonResponse({
                    'status': 'success',
                    'user_id': user_id,
                    'posture_data': {
                        'state': state_map.get(last_record.state, '未知'),
                        'risk_level': risk_map.get(last_record.posture_risk_level, '未知'),
                        'pitch': 0.0,
                        'roll': 0.0,
                        'yaw': 0.0
                    }
                })
            else:
                return JsonResponse({
                    'status': 'success',
                    'user_id': user_id,
                    'posture_data': {
                        'state': '站立',
                        'risk_level': '正常',
                        'pitch': 0.0,
                        'roll': 0.0,
                        'yaw': 0.0
                    }
                })
        except Exception as e:
            print(f"获取蓝牙数据异常: {str(e)}")
            return JsonResponse({'error': str(e)}, status=500)
    else:
        return JsonResponse({'error': 'Method not allowed'}, status=405)
