from django.urls import path
from .views import process_posture_data, register, login, send_verification_code, update_user_info, get_user_info, process_with_n8n, process_clothing_data, process_bluetooth_data, get_body_movement_data, start_bluetooth_receiver

urlpatterns = [
    path('login/', login, name='login'),
    path('register/', register, name='register'),
    path('send-code/', send_verification_code, name='send_verification_code'),
    path('info/', get_user_info, name='get_user_info'),
    path('update/', update_user_info, name='update_user_info'),
    path('n8n/', process_with_n8n, name='process_with_n8n'),
    path('clothing/', process_clothing_data, name='process_clothing_data'),
    path('bluetooth/', process_bluetooth_data, name='process_bluetooth_data'),
    path('bluetooth/start/', start_bluetooth_receiver, name='start_bluetooth_receiver'),
    path('process/', process_posture_data, name='process_posture'),
    path('body-movement/', get_body_movement_data, name='get_body_movement_data'),
]