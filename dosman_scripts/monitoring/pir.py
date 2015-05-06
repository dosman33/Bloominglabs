#!/usr/bin/python
#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#|R|a|s|p|b|e|r|r|y|P|i|-|S|p|y|.|c|o|.|u|k|
#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#
# pir_1.py
# Detect movement using a PIR module
#
# Author : Matt Hawkins
# Date   : 21/01/2013

# Import required Python libraries
import RPi.GPIO as GPIO
import time
import datetime

# Use BCM GPIO references
# instead of physical pin numbers
GPIO.setmode(GPIO.BCM)

# Define GPIO to use on Pi
GPIO_PIR = 20

#print "PIR Module Test (CTRL-C to exit)"

# Set pin as input
GPIO.setup(GPIO_PIR,GPIO.IN)      # Echo

# Setup log file
f = open("/var/log/motion01.log","a",0)

Current_State  = 0
Previous_State = 0

try:

  #print "Waiting for PIR to settle ..."

  # Loop until PIR output is 0
  while GPIO.input(GPIO_PIR)==1:
    Current_State  = 0    

  now = str(datetime.datetime.now()) + ' ' + str(time.time())
  print now + ' ready'
  f.write(now + ' ready\n')
  #print "Ready"     
    
  # Loop until users quits with CTRL-C
  while True :
   
    # Read PIR state
    Current_State = GPIO.input(GPIO_PIR)
   
    if Current_State==1 and Previous_State==0:
      # PIR is triggered
      #print "  Motion detected!"
      #print "  Motion detected! - "
      #now = datetime.datetime.now()
      #print str(now) + ' motion'
      now = str(datetime.datetime.now()) + ' ' + str(time.time())
      f.write(now + ' motion detected\n')

      # Record previous state
      Previous_State=1
    elif Current_State==0 and Previous_State==1:
      # PIR has returned to ready state
      #print "  Ready"
      #now = datetime.datetime.now()
      now = str(datetime.datetime.now()) + ' ' + str(time.time())
      #print str(now) + ' no motion'
      f.write(now + ' no motion\n')

      Previous_State=0
      
    # Wait for 10 milliseconds
    #time.sleep(0.01)      
    time.sleep(0.50)      
      
except KeyboardInterrupt:
  print "  Quit" 
  # close our log file
  f.close() 
  # Reset GPIO settings
  GPIO.cleanup()
