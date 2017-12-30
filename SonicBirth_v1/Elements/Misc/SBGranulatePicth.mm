/*
	Copyright 2005-2007 Antoine Missout
	Released under GPL.
	See http://www.gnu.org/copyleft/gpl.txt
*/
#import "SBGranulate.h"
#import "string.h"

#include <vector>

#define kRandomMax ((double)(0x7FFFFFFF))

class GrainPicth
{
public:
	enum
	{
		STATE_STOP = 0,
		STATE_ATTACK,
		STATE_SUSTAIN,
		STATE_DECAY,
		STATE_SILENCE
	} state;
	
	int attackCount;
	int sustainCount;
	int decayCount;
	int silenceCount;
	
	double bufferPos;
	double grainSpeed;
	
	double rampScale;
	double rampRate;
	
	GrainPicth()	:
		state(STATE_STOP),
		
		attackCount(0),
		sustainCount(0),
		decayCount(0),
		silenceCount(0),
		
		bufferPos(0),
		grainSpeed(1),
		
		rampScale(0),
		rampRate(0)
		{}
};

static const double kMaxGranuleLength = 1;
static const double kMaxLength = 10;

class GranulatePitchImp
{
public:
	GranulatePitchImp()
	{
		mBuffer = NULL;
		mBufferSize = 0;
		mBufferPos = 0;
	}
	
	~GranulatePitchImp()
	{
		delete mBuffer;
	}
	
	void prepare(int sr)
	{
		mSR = sr;
		int size = ((int)kMaxLength * 2 + (int)kMaxGranuleLength * 4 + 6) * sr;
		if (mBufferSize != size)
		{
			delete mBuffer;
			mBuffer = new double[size];
			mBufferSize = size;
		}
	}
	
	void reset()
	{
		mBufferPos = 0;
		memset(mBuffer, 0, mBufferSize * sizeof(double));
		
		int voices = mGrains.size();
		for (int v = 0; v < voices; v++)
			 mGrains[v].state = GrainPicth::STATE_STOP;
	}
	
	void setParams(	double delay, double drndness,
					double ramp, double voices,
					double length, double lrndness,
					double silence, double srndness,
					double pitch, double prndness)
	{
		double minLength = 10. / mSR;
	
		if (length < minLength) length = minLength;
		else if (length > kMaxGranuleLength) length = kMaxGranuleLength;
		
		if (delay < length) delay = length;
		else if (delay > kMaxLength) delay = kMaxLength;
		
		if (silence < 0) silence = 0;
		else if (silence > 10) silence = 10;
		
		if (voices < 1) voices = 1;
		else if (voices > 100) voices = 100;
		
		if (drndness < 0) drndness = 0;
		else if (drndness > 1) drndness = 1;
		
		if (lrndness < 0) lrndness = 0;
		else if (lrndness > 1) lrndness = 1;
		
		if (srndness < 0) srndness = 0;
		else if (srndness > 1) srndness = 1;
		
		if (prndness < 0) prndness = 0;
		else if (prndness > 1) prndness = 1;
		
		if (pitch >= 0)
		{
			if (pitch < 0.5) pitch = 0.5;
			else if (pitch > 5) pitch = 5;
		}
		else
		{
			if (pitch > -0.5) pitch = -0.5;
			else if (pitch < -5) pitch = -5;
		}
		
		if (ramp < 0) ramp = 0;
		else if (ramp > 100) ramp = 100;
		
		mRamp = ramp * 0.005; // scale between 0 and 0.5
		
		mDelay = (int)(delay * mSR);
		mDelayRandomness = drndness;

		mLength = (int)(length * mSR);
		mLengthRandomness = lrndness;
		
		mSilence = (int)(silence * mSR);
		mSilenceRandomness = srndness;
		
		mPitch = pitch;
		mPitchRandomness = prndness;
		
		int oldvoices = mGrains.size();
		int ivoices = (int)voices;
		if (ivoices < 1) ivoices = 1;
		
		mGrains.resize(ivoices);
		for (int i = oldvoices; i < ivoices; i++)
			 mGrains[i].state = GrainPicth::STATE_STOP;
		
		mGrainDelay = mLength / ivoices;
		if (mGrainDelay < 1) mGrainDelay = 1;
		
		mInvVoiceCount = 1. / ivoices;
	}
	
	double compute(double i)
	{
		// save sample
		mBuffer[mBufferPos++] = i;
		if (mBufferPos >= mBufferSize) mBufferPos = 0;
		
		int voices = mGrains.size();
		double o = 0;
		for (int v = 0; v < voices; v++)
		{
			GrainPicth &g = mGrains[v];
			
			if (g.state == GrainPicth::STATE_STOP)
			{
				// reset the gain
				double randomval = (double)random() * 1.9 /  kRandomMax - (1.9/2.);
				
				int count = (int)(mLength * (1 + mLengthRandomness * randomval));
				if (count < 10) count = 10;
				
				if (mRamp > 0)
				{
					int fade = (int)(mRamp * count);
					int maxFade = count >> 1;
					
					if (fade <= 0) fade = 1;
					else if (fade > maxFade) fade = maxFade;
					
					
					g.attackCount = fade;
					g.decayCount = fade;
					g.sustainCount = count - (fade << 1);
				
					g.state = GrainPicth::STATE_ATTACK;
					
					g.rampScale = g.rampRate = 1. / (fade + 1);
				}
				else
				{
					g.decayCount = 0;
					g.sustainCount = count;
					g.state = GrainPicth::STATE_SUSTAIN;
				}
				
				randomval = (double)random() * 1.9 /  kRandomMax - (1.9/2.);
				double pitch = mPitch * (1 + mPitchRandomness * randomval);
				if (pitch >= 0)
				{
					if (pitch < 0.5) pitch = 0.5;
					else if (pitch > 5) pitch = 5;
				}
				else
				{
					count = 0;
					if (pitch > -0.5) pitch = -0.5;
					else if (pitch < -5) pitch = -5;
				}
				g.grainSpeed = pitch;
				
				randomval = (double)random() * 1.9 /  kRandomMax - (1.9/2.);
				double delay = mDelay * (1 + mDelayRandomness * randomval);
				double pos = mBufferPos - delay - count - (mGrainDelay * v);
				while (pos < 0) pos += mBufferSize;
				g.bufferPos = pos;
				
				randomval = (double)random() * 1.9 /  kRandomMax - (1.9/2.);
				double silence = mSilence * (1 + mSilenceRandomness * randomval);
				g.silenceCount = (int)silence;
			}
			
			int ipos;
			switch(g.state)
			{
				case GrainPicth::STATE_ATTACK:
					ipos = (int)g.bufferPos;
					g.bufferPos += g.grainSpeed;
					//while (g.bufferPos < 0) g.bufferPos += mBufferSize;
					//while (g.bufferPos >= mBufferSize) g.bufferPos -= mBufferSize;
					ipos %= mBufferSize;
					if (ipos < 0) ipos += mBufferSize;
					
					o += mBuffer[ipos] * g.rampScale;
					g.rampScale += g.rampRate;
					
					if (--g.attackCount <= 0) g.state = GrainPicth::STATE_SUSTAIN;
					break;
					
				case GrainPicth::STATE_SUSTAIN:
					ipos = (int)g.bufferPos;
					g.bufferPos += g.grainSpeed;
					//while (g.bufferPos < 0) g.bufferPos += mBufferSize;
					//while (g.bufferPos >= mBufferSize) g.bufferPos -= mBufferSize;
					ipos %= mBufferSize;
					if (ipos < 0) ipos += mBufferSize;
				
					o += mBuffer[ipos];

					if (--g.sustainCount <= 0)
					{
						if (g.decayCount > 0) g.state = GrainPicth::STATE_DECAY;
						else if (g.silenceCount > 0) g.state = GrainPicth::STATE_SILENCE;
						else g.state = GrainPicth::STATE_STOP;
					}
					break;
					
				case GrainPicth::STATE_DECAY:
					ipos = (int)g.bufferPos;
					g.bufferPos += g.grainSpeed;
					//while (g.bufferPos < 0) g.bufferPos += mBufferSize;
					//while (g.bufferPos >= mBufferSize) g.bufferPos -= mBufferSize;
					ipos %= mBufferSize;
					if (ipos < 0) ipos += mBufferSize;
				
					g.rampScale -= g.rampRate;
					o += mBuffer[ipos] * g.rampScale;

					if (--g.decayCount <= 0)
					{
						if (g.silenceCount > 0) g.state = GrainPicth::STATE_SILENCE;
						else g.state = GrainPicth::STATE_STOP;
					}
					break;
					
				case GrainPicth::STATE_SILENCE:
					if (--g.silenceCount <= 0) g.state = GrainPicth::STATE_STOP;
					break;
					
				case GrainPicth::STATE_STOP: break; // impossible, but shuts up compiler
			}
		}
		
		return o * mInvVoiceCount;
	}
	
private:
	int mSR;
	
	int mBufferPos, mBufferSize;
	double *mBuffer;
	
	int mDelay, mGrainDelay, mLength, mSilence;
	double mPitch, mRamp, mDelayRandomness, mLengthRandomness;
	double mSilenceRandomness, mPitchRandomness, mInvVoiceCount;
	
	std::vector<GrainPicth> mGrains;
};

extern "C" void SBGranulatePicthPrivateCalcFunc(void *inObj, int count, int offset);
extern "C" void SBGranulatePicthPrivateCalcFuncImpl(int count, int offset,
									void *mModel, SBPrecision mPrecision,
									SBBuffer *pInputBuffers,
									SBBuffer *mAudioBuffers)
{
	if (count <= 0) return;
	
	GranulatePitchImp *imp = (GranulatePitchImp *)mModel;
	
	if (mPrecision == kFloatPrecision)
	{
		float *delay = pInputBuffers[1].floatData + offset;
		float *drndness = pInputBuffers[2].floatData + offset;
		float *ramp = pInputBuffers[3].floatData + offset;
		float *voices = pInputBuffers[4].floatData + offset;
		float *length = pInputBuffers[5].floatData + offset;
		float *lrndness = pInputBuffers[6].floatData + offset;
		float *silence = pInputBuffers[7].floatData + offset;
		float *srndness = pInputBuffers[8].floatData + offset;
		float *pitch = pInputBuffers[9].floatData + offset;
		float *prndness = pInputBuffers[10].floatData + offset;
		
		imp->setParams(	*delay, *drndness, *ramp, *voices, *length, *lrndness,
						*silence, *srndness, *pitch, *prndness);
		
		float *i = pInputBuffers[0].floatData + offset;
		float *o = mAudioBuffers[0].floatData + offset;

		while(count--)
			*o++ = imp->compute(*i++);
	}
	else if (mPrecision == kDoublePrecision)
	{
		double *delay = pInputBuffers[1].doubleData + offset;
		double *drndness = pInputBuffers[2].doubleData + offset;
		double *ramp = pInputBuffers[3].doubleData + offset;
		double *voices = pInputBuffers[4].doubleData + offset;
		double *length = pInputBuffers[5].doubleData + offset;
		double *lrndness = pInputBuffers[6].doubleData + offset;
		double *silence = pInputBuffers[7].doubleData + offset;
		double *srndness = pInputBuffers[8].doubleData + offset;
		double *pitch = pInputBuffers[9].doubleData + offset;
		double *prndness = pInputBuffers[10].doubleData + offset;
		
		imp->setParams(	*delay, *drndness, *ramp, *voices, *length, *lrndness,
						*silence, *srndness, *pitch, *prndness);
		
		double *i = pInputBuffers[0].doubleData + offset;
		double *o = mAudioBuffers[0].doubleData + offset;

		while(count--)
			*o++ = imp->compute(*i++);
	}
}


@implementation SBGranulatePicth

+ (NSString*) name
{
	return @"Granulate effect with pitch";
}

- (NSString*) name
{
	return @"granulate w/p";
}

+ (SBElementCategory) category
{
	return kMisc;
}

- (NSString*) informations
{
	return	@"Granulator effect with variable picth. "
			@"Delay is max delay in seconds to create grain from (max 10 seconds). "
			@"DRandomness is a value between 0 and 1 affecting the grain's delay."
			@"Ramp is a value between 0 and 100. At 0 no attack or decay is used. "
			@"At 100 it gives a triangular envelope, "
			@"at 50 a trapezoidal envelope. "
			@"Voices is the number of simultaneous grains (max 100). "
			@"Length is the duration of grains in seconds (max 1 second). "
			@"LRandomness is a value between 0 and 1 affecting the grain's length."
			@"Silence is the duration of silence between grains in seconds (max 10 seconds). "
			@"SRandomness is a value between 0 and 1 affecting the silence's length."
			@"Pitch is the grain playing speed (0.5 to 5) - can be negative. "
			@"PRandomness is a value between 0 and 1 affecting the pitch.";
}

- (void) reset
{
	[super reset];
	mImp->reset();
}

- (id) init
{
	self = [super init];
	if (self != nil)
	{
		mImp = new GranulatePitchImp();
		if (!mImp)
		{
			[self release];
			return nil;
		}
	
		pCalcFunc = SBGranulatePicthPrivateCalcFunc;

		[mInputNames addObject:@"i"];
		
		[mInputNames addObject:@"delay"];
		[mInputNames addObject:@"drndness"];
		[mInputNames addObject:@"ramp"];
		[mInputNames addObject:@"voices"];
		[mInputNames addObject:@"length"];
		[mInputNames addObject:@"lrndness"];
		[mInputNames addObject:@"silence"];
		[mInputNames addObject:@"srndness"];
		[mInputNames addObject:@"pitch"];
		[mInputNames addObject:@"prndness"];
		
		[mOutputNames addObject:@"o"];
	}
	return self;
}

- (void) dealloc
{
	delete mImp;
	[super dealloc];
}

- (void) specificPrepare
{
	mImp->prepare(mSampleRate);
}

@end
