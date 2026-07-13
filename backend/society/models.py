from django.db import models

class Society(models.Model):
    STATUS_CHOICES = [
        ('Active', 'Active'),
        ('Inactive', 'Inactive'),
    ]
    name = models.CharField(max_length=255)
    address = models.TextField()
    city = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    pincode = models.CharField(max_length=20)
    contact_person = models.CharField(max_length=255)
    contact_number = models.CharField(max_length=20)
    email = models.EmailField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Active')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

class BlockTower(models.Model):
    society = models.ForeignKey(Society, on_delete=models.CASCADE, related_name='blocks')
    name = models.CharField(max_length=100)
    total_floors = models.IntegerField()

    def __str__(self):
        return f"{self.society.name} - {self.name}"

class Flat(models.Model):
    block = models.ForeignKey(BlockTower, on_delete=models.CASCADE, related_name='flats')
    flat_number = models.CharField(max_length=50)
    floor = models.IntegerField()
    type = models.CharField(max_length=50)
    occupied = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.block.name} - Flat {self.flat_number}"

