/*
	Copyright 2005-2007 Antoine Missout
	Released under GPL.
	See http://www.gnu.org/copyleft/gpl.txt
*/
#import "SBLowpass.h"

#include <math.h> // for M_PI

@implementation SBLowpass

+ (NSString*) name
{
	return @"Lowpass";
}

- (NSString*) name
{
	return @"lpass";
}

- (NSString*) informations
{
	return @"Lowpass filter, 12/db octave (Butterworth), with variable cutoff frequency (clamped to [1, 20000]).";
}

- (void) specificPrepare
{
	int i;
	for(i = 0; i < kCoeffCount; i++)
	{
		double f = i + kCoeffBase;
		
		if (f >= (mSampleRate/2.))
		{
			// passthrough
			mCoeffFloat[i].a0 = 1;
			mCoeffFloat[i].a1 = 0;
			mCoeffFloat[i].a2 = 0;
			mCoeffFloat[i].b1 = 0;
			mCoeffFloat[i].b2 = 0;
			
			mCoeffDouble[i].a0 = 1;
			mCoeffDouble[i].a1 = 0;
			mCoeffDouble[i].a2 = 0;
			mCoeffDouble[i].b1 = 0;
			mCoeffDouble[i].b2 = 0;
		}
		else
		{
			double c = 1. / tan(M_PI * f / mSampleRate);
			double g = 1.;
			double p = sqrt(2.);
			
			double k = c*c + p*c + g;
			
			double a0 = 1. / (g*k);
			double a1 = a0+a0;
			double a2 = a0;
			double b1 = 2. * (g -  c*c) / k;
			double b2 = (c*c - p*c +g) / k;
			
			//if (f == 300) printf("%d %.20f %.20f %.20f\n", mSampleRate, a0, b1, b2);
			
			mCoeffFloat[i].a0 = a0;
			mCoeffFloat[i].a1 = a1;
			mCoeffFloat[i].a2 = a2;
			mCoeffFloat[i].b1 = -b1;
			mCoeffFloat[i].b2 = -b2;
			
			mCoeffDouble[i].a0 = a0;
			mCoeffDouble[i].a1 = a1;
			mCoeffDouble[i].a2 = a2;
			mCoeffDouble[i].b1 = -b1;
			mCoeffDouble[i].b2 = -b2;
		}
	}
}

@end
