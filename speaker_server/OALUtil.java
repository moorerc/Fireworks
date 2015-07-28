/* 
 * Copyright (c) 2006 Karsten Schmidt
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * http://creativecommons.org/licenses/LGPL/2.1/
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

import javax.sound.sampled.UnsupportedAudioFileException;
import com.jogamp.openal.sound3d.*;
import com.jogamp.openal.eax.*;
import com.jogamp.openal.*;
import com.jogamp.openal.util.*;
import jogamp.openal.*;

import java.io.*;

public class OALUtil {

  private AL al;
  private ALC alc;

  public OALUtil() {
    try {
	initOpenAL();
    } 
    catch (ALException e) {
	throw new RuntimeException("OpenAL could not be initialized: "
	  + e.getMessage());
    }
  }

  private void initOpenAL() throws ALException {
    AudioSystem3D.init();

    alc = ALFactory.getALC();
    al = ALFactory.getAL();

    ALCdevice device;
    ALCcontext context;
    String deviceID;

    // Get handle to default device.
    device = alc.alcOpenDevice(null);
    if (device == null) {
	throw new ALException("Error opening default OpenAL device");
    }

    deviceID = alc.alcGetString(device, ALC.ALC_DEVICE_SPECIFIER);
    if (deviceID == null) {
	throw new ALException(
	"Error getting specifier for default OpenAL device");
    }

    System.out.println("Using device " + deviceID);

    // Create audio context.
    context = alc.alcCreateContext(device, null);
    if (context == null) {
	throw new ALException("Can't create OpenAL context");
    }
    alc.alcMakeContextCurrent(context);

    if (alc.alcGetError(device) != ALC.ALC_NO_ERROR) {
	throw new ALException("Unable to make context current");
    }
  }

  public void cleanup() {
    ALCcontext curContext;
    ALCdevice curDevice;

    curContext = alc.alcGetCurrentContext();
    curDevice = alc.alcGetContextsDevice(curContext);
    alc.alcMakeContextCurrent(null);
    alc.alcDestroyContext(curContext);
    alc.alcCloseDevice(curDevice);

    al = null;
    alc = null;
  }

  public Buffer loadBuffer(InputStream is) throws UnsupportedAudioFileException, IOException {
    Buffer[] buf = AudioSystem3D.generateBuffers(1);
    WAVData wd = WAVLoader.loadFromStream(is);
    buf[0].configure(wd.data, wd.format, wd.freq);
    return buf[0];
  }

  public Buffer loadBuffer(String fileName) throws IOException, UnsupportedAudioFileException {
    return AudioSystem3D.loadBuffer(fileName);
  }

  public Source loadSource(InputStream stream) throws UnsupportedAudioFileException, IOException {
    return AudioSystem3D.generateSource(loadBuffer(stream));
  }

  public Listener getListener() {
    return AudioSystem3D.getListener();
  }

  public Source createSource(Buffer buffer) {
    return AudioSystem3D.generateSource(buffer);
  }
} 
