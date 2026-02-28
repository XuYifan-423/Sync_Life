from django.core.management.base import BaseCommand
from django.utils import timezone
from django.db import connection
from posture.models import PostureRecord

class Command(BaseCommand):
    help = '每天零点清理最早一天的数据，保持数据量在30天以内'

    def handle(self, *args, **options):
        self.stdout.write("开始检查是否需要清理数据...")
        self.stdout.write("=" * 50)
        
        try:
            # 获取第一条记录（最早的）
            earliest_record = PostureRecord.objects.order_by('start_time').first()
            
            if not earliest_record:
                self.stdout.write(self.style.WARNING("数据库中没有数据"))
                return
            
            earliest_time = earliest_record.start_time
            now = timezone.now()
            
            # 计算第一条记录和今天的时间间隔（天数）
            time_diff = (now - earliest_time).days
            
            self.stdout.write(f"最早记录时间: {earliest_time}")
            self.stdout.write(f"当前时间: {now}")
            self.stdout.write(f"时间间隔: {time_diff} 天")
            
            # 如果间隔超过30天，循环删除最早的数据，直到间隔在30天以内
            if time_diff > 30:
                delete_count = 0
                
                while True:
                    # 获取最早的记录
                    earliest_record = PostureRecord.objects.order_by('start_time').first()
                    
                    if not earliest_record:
                        break
                    
                    # 计算这条记录和今天的时间间隔
                    time_diff = (now - earliest_record.start_time).days
                    
                    # 如果间隔在30天以内，停止删除
                    if time_diff <= 30:
                        break
                    
                    # 删除这条记录
                    earliest_record.delete()
                    delete_count += 1
                    
                    # 每删除100条输出一次进度
                    if delete_count % 100 == 0:
                        self.stdout.write(f"已删除 {delete_count} 条记录...")
                
                self.stdout.write(self.style.SUCCESS(f"已删除 {delete_count} 条记录"))
                
                # 重置序列
                remaining_count = PostureRecord.objects.count()
                if remaining_count > 0:
                    with connection.cursor() as cursor:
                        cursor.execute("""
                            SELECT pg_get_serial_sequence('posture_posturerecord', 'record_id')
                        """)
                        sequence_name = cursor.fetchone()[0]
                        
                        cursor.execute(f"SELECT MAX(record_id) FROM posture_posturerecord")
                        max_id = cursor.fetchone()[0]
                        
                        cursor.execute(f"ALTER SEQUENCE {sequence_name} RESTART WITH {max_id + 1}")
                    
                    connection.commit()
                    self.stdout.write(self.style.SUCCESS(f"已将序列重置为 {max_id + 1}"))
                
                self.stdout.write(self.style.SUCCESS(f"剩余记录数: {remaining_count}"))
                self.stdout.write(self.style.SUCCESS("\n清理完成！"))
            else:
                self.stdout.write(self.style.SUCCESS(f"时间间隔未超过30天，无需清理"))
            
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"清理过程中出错: {e}"))
            import traceback
            traceback.print_exc()
