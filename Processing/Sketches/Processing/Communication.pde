/*
 * File       Communiction class for Freenove Quadruped Robot
 * Author     Ethan Pan @ Freenove (support@freenove.com)
 * Date       2017/4/23
 * Copyright  Copyright © Freenove (http://www.freenove.com)
 * License    Creative Commons Attribution ShareAlike 3.0
 *            (http://creativecommons.org/licenses/by-sa/3.0/legalcode)
 * -----------------------------------------------------------------------------------------------*/

import processing.serial.*;
import processing.net.*; 

class Communication {
  private PApplet parent;

  Communication(PApplet pApplet) {
    parent = pApplet;
  }

  private int readTimeout = 400;
  private final int maxSendTimes = 3;

  public boolean SendCommand(byte[] outData) {
    byte[] inData;

    for (int i = 0; i < maxSendTimes; i++) {
      readTimeout = 400;
      if (isSerialAvailable) {
        serial.clear();
        SerialWrite(outData);
        inData = SerialRead();
        if (inData != null) {
          if (inData[0] == Command.commandDone) {
            return true;
          } else if (inData[0] == Command.commandStart) {
            WaitCommandDone();
            return true;
          }
        }
      }
      if (isClientAvailable) {
        client.clear();
        ClientWrite(outData);
        if(outData[0] == Command.requestMoveBodyTo || outData[0] == Command.requestRotateBodyTo)
          return true;
        inData = ClientRead();
        if (inData != null) {
          if (inData[0] == Command.commandDone) {
            return true;
          } else if (inData[0] == Command.commandStart) {
            WaitCommandDone();
            return true;
          }
        }
      }
    }
    return false;
  }

  private boolean WaitCommandDone() {
    readTimeout = 5000;
    byte[] data;

    if (isSerialAvailable) {
      data = SerialRead();
      if (data != null)
        if (data[0] == Command.commandDone)
          return true;
    }
    if (isClientAvailable) {
      data = ClientRead();
      if (data != null)
        if (data[0] == Command.commandDone)
          return true;
    }
    return false;
  }

  private Client client; 
  public boolean isClientAvailable = false;

  public boolean StartClient() {
    StopClient();
    println(Time() + "Client connection start: connect to port...");

    try {
      client = new Client(parent, "192.168.4.1", 65535);
      if (client.active())
      {
        println(Time() + "Client connection success");
        isClientAvailable = true;
        return true;
      }
    }
    catch (Exception e) {
      e.printStackTrace();
    }

    println(Time() + "Client connection failed");
    return false;
  }

  private void ClientWrite(byte[] data) {
    byte[] dataWrite = new byte[data.length + 2];
    dataWrite[0] = Command.transStart;
    for (int i = 0; i < data.length; i++)
      dataWrite[i+1] = data[i];
    dataWrite[data.length + 1] = Command.transEnd;
    client.write(dataWrite);
  }

  private byte[] ClientRead() {
    byte[] inData = new byte[16];
    int inDataNum = 0;
    int startTime = millis();

    while (true) {
      if (client.available() > 0) {
        byte[] inTemp = new byte[1];
        client.readBytes(inTemp);
        byte inByte = inTemp[0];

        if (inByte == Command.transStart)
          inDataNum = 0;
        inData[inDataNum++] = inByte;
        if (inByte == Command.transEnd)
          if (inData[0] == Command.transStart)
            break;
        startTime = millis();
      }
      if (millis () - startTime > readTimeout) {
        println(Time() + "Client read failed: time out");
        return null;
      }
      delay(2);
    } 

    if (inData[0] == Command.transStart && inData[inDataNum - 1] == Command.transEnd) {
      byte[] data = new byte[inDataNum - 2];
      for (int i = 0; i < inDataNum - 2; i++)
        data[i] = inData[i + 1];
      return data;
    }

    println(Time() + "Client read failed: incorrect data format");
    return null;
  }

  public void StopClient() {
    if (isClientAvailable) {
      isClientAvailable = false;
      client.stop();
      println(Time() + "Client connection stop");
    }
  }

  private Serial serial;
  private String serialName;
  public boolean isSerialAvailable = false;

  public boolean StartSerial() {
    StopSerial();
    println(Time() + "Serial connection start: detecte serial...");
    String[] serialNames = Serial.list();
    if (serialNames.length == 0) {
      println(Time() + "Serial connection failed: no serial detected");
      return false;
    }
    print(Time() + "Serial detected: ");
    for (int i = 0; i < serialNames.length; i++)
      print(serialNames[i] + " ");
    println("");
    for (int i = 0; i < serialNames.length; i++) {
      println(Time() + "Serial connection attempt: " + serialNames[i] + "...");
      try {
        serial = new Serial(parent, serialNames[i], 115200);
        serial.clear();
        delay(1600);
        SerialWrite(serial, new byte[]{Command.requestEcho});
        readTimeout = 400;
        byte[] data = SerialRead(serial);
        if (data != null) {
          if (data[0] == Command.echo) {
            serialName = serialNames[i];
            println(Time() + "Serial connection success: " + this.serialName);
            isSerialAvailable = true;
            return true;
          }
        }
        serial.stop();
      }
      catch (Exception e) {
        e.printStackTrace();
      }
    }
    println(Time() + "Serial connection failed: detected serial, no serial responded");
    return false;
  }

  private boolean SerialWrite(byte[] data) {
    if (isSerialAvailable) {
      SerialWrite(serial, data);
      return true;
    } else
      println(Time() + "Serial write failed: serial is not available");
    return false;
  }

  private byte[] SerialRead() {
    if (isSerialAvailable) {
      byte[] data = SerialRead(serial);
      if (data != null)
        return data;
    } else
      println(Time() + "Serial read failed: serial is not available");
    return null;
  }

  private void SerialWrite(Serial serial, byte[] data) {
    byte[] dataWrite = new byte[data.length + 2];
    dataWrite[0] = Command.transStart;
    for (int i = 0; i < data.length; i++)
      dataWrite[i+1] = data[i];
    dataWrite[data.length + 1] = Command.transEnd;
    serial.write(dataWrite);
  }

  private byte[] SerialRead(Serial serial) {
    byte[] inData = new byte[16];
    int inDataNum = 0;
    int startTime = millis();

    while (true) {
      if (serial.available() > 0) {
        byte[] inTemp = new byte[1];
        serial.readBytes(inTemp);
        byte inByte = inTemp[0];

        if (inByte == Command.transStart)
          inDataNum = 0;
        inData[inDataNum++] = inByte;
        if (inByte == Command.transEnd)
          if (inData[0] == Command.transStart)
            break;
        startTime = millis();
      }
      if (millis () - startTime > readTimeout) {
        println(Time() + "Serial read failed: time out");
        return null;
      }
      delay(2);
    } 

    if (inData[0] == Command.transStart && inData[inDataNum - 1] == Command.transEnd) {
      byte[] data = new byte[inDataNum - 2];
      for (int i = 0; i < inDataNum - 2; i++)
        data[i] = inData[i + 1];
      return data;
    }

    println(Time() + "Serial read failed: incorrect data format");
    return null;
  }

  public void StopSerial() {
    if (isSerialAvailable) {
      isSerialAvailable = false;
      serial.stop();
      println(Time() + "Serial connection stop");
    }
  }

  public String Time() {
    return hour() + ":" + minute() + ":" + second() + " ";
  }
}