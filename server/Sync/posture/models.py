from django.db import models
from django.contrib.auth.hashers import make_password, check_password
from enum import Enum

class State(Enum):
    LIE = 0
    STAND = 1
    SIT = 2
    WALK = 3
    RUN = 4

class AgeGroup(Enum):
    YOUTH = "YOUTH"
    PRIME = "PRIME"
    MIDDLE = "MIDDLE"
    SENIOR = "SENIOR"

class PostureRiskLevel(Enum):
    NORMAL = "NORMAL"
    MILD_RISK = "MILD_RISK"
    SEVERE_RISK = "SEVERE_RISK"

class User(models.Model):
    id = models.AutoField(primary_key=True)
    phone = models.CharField(max_length=20)
    email = models.EmailField(unique=True, blank=True, null=True)
    password = models.CharField(max_length=128, blank=True, null=True)
    identity = models.CharField(max_length=30, blank=True, null=True)
    age = models.IntegerField()
    age_group = models.CharField(max_length=10, choices=[(ag.value, ag.value) for ag in AgeGroup])
    weight = models.FloatField()
    height = models.FloatField()
    ills = models.TextField(blank=True, null=True)
    is_verified = models.BooleanField(default=False)

    def set_password(self, raw_password):
        self.password = make_password(raw_password)

    def check_password(self, raw_password):
        return check_password(raw_password, self.password)

    def save(self, *args, **kwargs):
        if not self.age_group:
            if 11 <= self.age <= 24:
                self.age_group = AgeGroup.YOUTH.value
            elif 25 <= self.age <= 44:
                self.age_group = AgeGroup.PRIME.value
            elif 45 <= self.age <= 59:
                self.age_group = AgeGroup.MIDDLE.value
            else:
                self.age_group = AgeGroup.SENIOR.value
        super().save(*args, **kwargs)

class PostureRecord(models.Model):
    record_id = models.AutoField(primary_key=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    # 生成数据后恢复为自动添加时间
    start_time = models.DateTimeField(auto_now_add=True)
    end_time = models.DateTimeField(blank=True, null=True)
    state = models.IntegerField(choices=[(s.value, s.name) for s in State])
    trunk_stable_angle = models.FloatField()
    posture_risk_level = models.CharField(max_length=20, choices=[(prl.value, prl.value) for prl in PostureRiskLevel])
    duration = models.FloatField(blank=True, null=True)

    def save(self, *args, **kwargs):
        if self.end_time and not self.duration:
            self.duration = (self.end_time - self.start_time).total_seconds()
        super().save(*args, **kwargs)
