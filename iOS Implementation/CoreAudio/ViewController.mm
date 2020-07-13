//
//  ViewController.m
//  CoreAudio
//
//  Created by Shankar, Nikhil on 4/4/17.
//  Copyright © 2017 default. All rights reserved.
//

#import "ViewController.h"
#import "FIR.h"

#define kOutputBus 0
#define kInputBus 1
#define SHORT2FLOAT 1/32768.0
#define FLOAT2SHORT 32768.0;
#define FRAMESIZE 256
#define SAMPLINGFREQUENCY 48000
#define MAXIT 1000
#define EULER 0.5772156649
#define FPMIN 1.0e-30
#define EPS  1.0e-7f
#define pi 3.1415926535897932384626433832795
#ifndef min
#define min( a, b ) ( ((a) < (b)) ? (a) : (b) )
#endif
int nFFT=512;
//static float endSamples[3] = {0,0,0};
//int FFT=1024;
//static float *magnitudeRight =(float*)calloc(nFFT/2, sizeof(float));
//static float *magnitudeLeft =(float*)calloc(nFFT/2, sizeof(float));
static float *noise_mean = (float*)calloc(nFFT, sizeof(float));
static float *noise_mu2 = (float*)calloc(nFFT, sizeof(float));
static float *sig2 = (float*)calloc(nFFT, sizeof(float));
static float *gammak = (float*)calloc(nFFT, sizeof(float));
static float *ksi = (float*)calloc(nFFT, sizeof(float));
static float *Xk_prev = (float*)calloc(nFFT, sizeof(float));
static float *log_sigma_k = (float*)calloc(nFFT, sizeof(float));
static float *noise_pow = (float*)calloc(nFFT, sizeof(float));
static float *vk = (float*)calloc(nFFT, sizeof(float));
static float *A = (float*)calloc(nFFT, sizeof(float));
static float *ei_vk = (float*)calloc(nFFT, sizeof(float));
static float *hw = (float*)calloc(nFFT, sizeof(float));
static float *evk = (float*)calloc(nFFT, sizeof(float));
static float *Lambda = (float*)calloc(nFFT, sizeof(float));
static float *pSAP = (float*)calloc(nFFT, sizeof(float));
static float* ensig = ( float *)calloc(nFFT, sizeof( float));
static float* HPF = ( float*)calloc(2*(nFFT), sizeof( float));
static float* H = ( float*)calloc((nFFT), sizeof( float));
static float *fftmagoutput = (float*)calloc(nFFT, sizeof(float));
//static float *phase = (float*)calloc(nFFT, sizeof(float));
//static float *h=(float*)calloc(nFFT,sizeof(float));
//long double* nsig = (long double *)calloc(nFFT, sizeof(long double));
float total_noisepower=0;
float total_speechpower=0;
float sum_ensig = 0;
float sum_nsig = 0;
float PRT;
float N;
float aa = 0.98;
float eta = 0.15;
float beta=0.5;
float max;
float ksi_min = (float)pow(10,((float)-25 /(float)10));
float sum_log_sigma_k = 0;
float vad_decision;
float qk = 0.3;
float qkr = (1 - qk) / qk;;
//float epsilon =  (float)pow(8.854,-12);
float epsilon = 0.001;
//float total_noisepower=0;
//float total_speechpower=0;
////float SNR_db;
char SNR_db_char;
int count=0;
int SPU = 0;
static float SNR_db;
//float *magnitudeLeft, *magnitudeRight, *phaseLeft, *phaseRight, *fifoOutput;
//float sum_ensig;
//float beta;
int on;
int frameCounter=0;
float snr_counter=0;
float sum_SNR=0;
float snr_avg;
Transform *X;
Transform *Y;
int k=1;
float np,sp;
float *win = (float*)malloc(nFFT* sizeof(float));
float *sys_win = (float*)malloc(FRAMESIZE* sizeof(float));
static float *output_final = (float*)calloc(FRAMESIZE, sizeof(float));
static float *output_old = (float*)calloc(FRAMESIZE, sizeof(float));
static float *in_buffer = (float*)calloc(nFFT, sizeof(float));
static float *in_prev = (float*)calloc(FRAMESIZE, sizeof(float));
double expint_new(int n, double x);
//static float *phase = (float*)calloc(nFFT, sizeof(float));
static float *input = (float*)calloc(FRAMESIZE, sizeof(float));
static float *float_output = (float*)calloc(nFFT, sizeof(float));

//static short *buffer = (short*)calloc(FRAMESIZE/sizeof(short), sizeof(short));
//static short *output = (short*)calloc(FRAMESIZE/sizeof(short), sizeof(short));

AURenderCallbackStruct callbackStruct;
AudioUnit au;
AudioBuffer tempBuffer;

@interface ViewController ()

@end

@implementation ViewController

@synthesize betaSlider;
@synthesize EnhancedSwitch;
@synthesize betaLabel;
@synthesize setBeta;
@synthesize stepper;
@synthesize snrdisplay;
@synthesize volumeslider;

-(void) updateBeta{
    x=stepper.value;
     betaLabel.text=[ NSString stringWithFormat:@"%f",x];
    
}

-(void) updateBeta1{
    x = 0.7;
    betaLabel.text=[ NSString stringWithFormat:@"%f",0.9];
    betaSlider.value = 0.9;
}

static OSStatus playbackCallback(void *inRefCon,AudioUnitRenderActionFlags *ioActionFlags,const AudioTimeStamp *inTimeStamp,UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    
    for (int i=0; i < ioData->mNumberBuffers; i++) {
        AudioBuffer buffer = ioData->mBuffers[i];
        UInt32 size = min(buffer.mDataByteSize, tempBuffer.mDataByteSize);
        memcpy(buffer.mData, tempBuffer.mData, size);
        buffer.mDataByteSize = size;
    }
    return noErr;
}

static OSStatus recordingCallback(void *inRefCon,AudioUnitRenderActionFlags *ioActionFlags,const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    
    AudioBuffer buffer;
    ViewController* view = (__bridge ViewController *)(inRefCon);
    
    buffer.mNumberChannels = 1;
    buffer.mDataByteSize = inNumberFrames * 2;
    buffer.mData = malloc( inNumberFrames * 2 );
    
    // Put buffer in a AudioBufferList
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0] = buffer;
    
    AudioUnitRender(au, ioActionFlags, inTimeStamp,inBusNumber,inNumberFrames,&bufferList);
    
    [view processAudio:&bufferList];
    // printf("%f\n",buffer);
    
    return noErr;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    volumeslider.value=[[MPMusicPlayerController applicationMusicPlayer] volume];
    betaLabel.text = @"0.5";
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayAndRecord error: NULL];
    [[AVAudioSession sharedInstance] setMode: AVAudioSessionModeVideoRecording error:NULL];
    [[AVAudioSession sharedInstance] setPreferredSampleRate:SAMPLINGFREQUENCY error:NULL];
    [[AVAudioSession sharedInstance]
     setPreferredIOBufferDuration:(float)FRAMESIZE/(float)SAMPLINGFREQUENCY error:NULL];
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    AudioComponent component = AudioComponentFindNext(NULL, &desc);
    if (AudioComponentInstanceNew(component, &au) != 0) abort();
    
    UInt32 value = 1;
    if (AudioUnitSetProperty(au, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &value,
                             sizeof(value))) abort();
    value = 1;
    if (AudioUnitSetProperty(au, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &value,
                             sizeof(value))) abort();
    
    AudioStreamBasicDescription format;
    format.mSampleRate = 0;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagIsSignedInteger;
    format.mFramesPerPacket = 1;
    format.mChannelsPerFrame = 1;
    format.mBitsPerChannel = 16;
    format.mBytesPerPacket = 2;
    format.mBytesPerFrame = 2;
    
    if (AudioUnitSetProperty(au, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &format,
                             sizeof(format))) abort();
    if (AudioUnitSetProperty(au, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &format,
                             sizeof(format))) abort();
    // Set input callback
    
    callbackStruct.inputProc = recordingCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    AudioUnitSetProperty(au, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, kInputBus,  &callbackStruct, sizeof(callbackStruct));
    
    // Set output callback
    callbackStruct.inputProc = playbackCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    AudioUnitSetProperty(au, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, kOutputBus,&callbackStruct, sizeof(callbackStruct));
    tempBuffer.mNumberChannels = 1;
    tempBuffer.mDataByteSize = FRAMESIZE * 2;
    tempBuffer.mData = malloc( FRAMESIZE * 2 );
    AudioUnitInitialize(au);
    AudioOutputUnitStart(au);
       // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) processAudio: (AudioBufferList*) bufferList{
    AudioBuffer sourceBuffer = bufferList->mBuffers[0];
   // short *buffer = (short*)calloc(sourceBuffer.mDataByteSize);
    //short *output =(short*)calloc(sourceBuffer.mDataByteSize);
    
    for (int i = 0; i < nFFT; i++)
    {
        win[i] = 0.5 * (1 - cosf(2 * M_PI*(i + 1) / (nFFT + 1)));
    }
    for (int i = 0; i < FRAMESIZE; i++)
    {
        sys_win[i] = 1 / (win[i] + win[i + FRAMESIZE]);
    }

   // static float *input1 = (float*)calloc(nFFT, sizeof(float));
   // static float *store_buffer = (float*)calloc(FRAMESIZE, sizeof(float));
    static short *buffer = (short*)calloc(sourceBuffer.mDataByteSize/sizeof(short), sizeof(short));
    static short *output = (short*)calloc(sourceBuffer.mDataByteSize/sizeof(short), sizeof(short));
    //static float *float_output1 = (float*)calloc(nFFT, sizeof(float));

    memcpy(buffer, bufferList->mBuffers[0].mData, bufferList->mBuffers[0].mDataByteSize);
    
    for (int i = 0; i < FRAMESIZE; i++) {
        input[i] = buffer[i] * SHORT2FLOAT;
       // printf("%f\n",input[i]);
    }
 if(on==0)
    {
        for(int i =0;i<FRAMESIZE;i++)
        {
        float_output[i]=input[i];
    }
    }




 if(on==1)
    {
        X=newTransform(nFFT);
        Y=newTransform(nFFT);
        X->doTransform(X,in_buffer);
        transformMagnitude(X, fftmagoutput);
        frameCounter++;
        for(int i =0;i<FRAMESIZE;i++)
        {
            in_buffer[i]=in_prev[i] * win[i];
            in_prev[i]=input[i];
            in_buffer[i+FRAMESIZE]=input[i] * win[i+FRAMESIZE];
        }


        beta=x;
        if (beta==0)
        {
            beta=0.5;
        }
            if(frameCounter<=6)
            {
                for (int i = 0; i < nFFT; i++)
                {
                noise_mean[i] += fftmagoutput[i];
               //printf("%f\n",noise_mean[i]);
                }
            }

        if(frameCounter==7)
        {
            for (int i = 0; i < nFFT; i++)
           {
                noise_mu2[i]=pow(noise_mean[i]/7,2);
                //printf("%f\n",noise_mu2[i]);

            }
        }
        np=noise_mu2[0];
        for(int i=1;i<nFFT;i++)
        {
            if(noise_mu2[i]>np)
            {
                np=noise_mu2[i];
            }
        }
        if(frameCounter>=7)
        {
            for (int i = 0; i < nFFT; i++)
            {
                sig2[i] = pow(fftmagoutput[i], 2);


               if( noise_mu2[i]==0)
                {
              noise_mu2[i] = noise_mu2[i] + epsilon;
              }
                gammak[i] = sig2[i] / noise_mu2[i] < 40 ? sig2[i] / noise_mu2[i] : 40;
               // printf("%f\n",gammak[i]);

            if (frameCounter == 7)
            {
               // for (int i = 0; i < nFFT; i++) {
                    max = gammak[i] - 1 > 0 ? gammak[i] - 1 : 0;
                    ksi[i] = aa + (1 - aa) * max;
                    // printf("%f\n",ksi[i]);
           // }
            }
            else
            {

                    max = gammak[i] - 1 > 0 ? gammak[i] - 1 : 0;
                    ksi[i] = aa * (Xk_prev[i] / noise_mu2[i]) + (1 - aa) * max;
                    ksi[i] = ksi_min > ksi[i] ? ksi_min : ksi[i];
                    // printf("%f\n",Xk_prev[i]);
                }


                sum_log_sigma_k = 0;
                log_sigma_k[i] = gammak[i] * ksi[i] / (1 + ksi[i]) - log(1 + ksi[i]);
           // if(log_sigma_k[i]<100)
           // {
            sum_log_sigma_k += log_sigma_k[i];
           //
            }
            // printf("%f\n",sum_log_sigma_k);
            vad_decision = sum_log_sigma_k / (nFFT);

            //__android_log_print(ANDROID_LOG_VERBOSE, "MyApp", "The value of SNR_db is %f",vad_decision );
            if (vad_decision < eta)// % noise on
            {
                count = count + 1;
                //printf("%f\n",ksi[i]);
                for (int i = 0; i < nFFT; i++)
                {
                    noise_pow[i] = noise_pow[i] + noise_mu2[i];
                    noise_mu2[i] = noise_pow[i] / count;
                }
            }
            float muu = 1.5;
            float ve = 0.1;
            
            for (int i = 0; i < nFFT; i++)
            {
                A[i] = ksi[i]  / (1 + ksi[i]);
                vk[i] = ksi[i] * gammak[i] / (1 + ksi[i]);
//                hw[i] = (ksi[i] + sqrt(pow(ksi[i], 2) + ((2*beta)*(beta + ksi[i])) * ksi[i] / (gammak[i]+epsilon))) / (2*beta * (beta + ksi[i])); //beta parameter to control amount of noise reduction
                hw[i] = 0.5-muu/(4*sqrt(ksi[i]))+sqrt(pow((0.5-2.5/(4*sqrt(ksi[i]))),2) + ve/(2*gammak[i]));
                
                sum_ensig += pow(ensig[i], 2);
                sum_nsig += pow(fftmagoutput[i], 2);
                
            }

            float PR = sum_ensig/sum_nsig;
           // printf("%f\n",PR);

            if (PR >= 0.4)
                PRT = 1;
            else
                PRT = PR;

            if (PRT == 1)
                N = 1;
            else
                N = 2 * round((1 - PRT / 0.4) * 10 ) + 1;

            //printf("%f\n",N);
            for (int i = 0; i < (int) N; i++)
                H[i] = 1 / N;
            //    H(1:N) = 1 / N;

            for (int i = 0; i < N + nFFT - 1; i++)
            {
                int kmin, kmax, k;

                HPF[i] = 0;

                kmin = (i >= nFFT - 1) ? i - (nFFT - 1) : 0;
                kmax = (i < N - 1) ? i : N - 1;

                for (k = kmin; k <= kmax; k++)
                    HPF[i] += H[k] * sqrt(hw[i - k]* hw[i - k]);


                if(beta<=0.8)
                {
                    HPF[i]=1;
                }
            }

                for (int i = 0; i < nFFT; i++)
                {
                    fftmagoutput[i] = fftmagoutput[i] * HPF[i];

                    X->real[i]=X->real[i]*HPF[i];
                    X->imaginary[i]=X->imaginary[i]*HPF[i];

                    ensig[i]=fftmagoutput[i];

                   if (fftmagoutput[i]<100)
                   {
                        // total_speechpower+=magnitudeLeft[i]*magnitudeLeft[i];
                        total_speechpower+=pow(fftmagoutput[i],2);
                    }
                    if(noise_pow[i]<100)
                    {
                        total_noisepower+=noise_pow[i];
                    }

                Xk_prev[i] = pow(fftmagoutput[i],2);
                }
        }
        Y->invTransform(Y,X->real,X->imaginary);
        sp=Y->real[0];
        for(int i=1;i<FRAMESIZE;i++)
        {
            if(Y->real[i]>sp)
            {
                sp=Y->real[i];
            }
        }
        for(int i=0;i<nFFT;i++)
        {
            SNR_db+=gammak[i];
        }
        SNR_db=(log10(total_noisepower/total_speechpower))-2;
        for(int i=0;i<FRAMESIZE;i++)
        {
            output_final[i]=(output_old[i]+Y->real[i])*sys_win[i];
            output_old[i]=Y->real[i+FRAMESIZE];
        }




       fir(output_final,float_output,FRAMESIZE);



        destroyTransform(X);
        destroyTransform(Y);

    }
        for (int i = 0; i < FRAMESIZE; i++)
        {
        float_output[i]=float_output[i]*2;
        output[i] = float_output[i] * FLOAT2SHORT ;
        //output[i]=output[i]*3;
        //printf("%f\n",float_output[i]);
        }
    
    if (tempBuffer.mDataByteSize != sourceBuffer.mDataByteSize)
    {
        free(tempBuffer.mData);
        tempBuffer.mDataByteSize = sourceBuffer.mDataByteSize;
        tempBuffer.mData = malloc(sourceBuffer.mDataByteSize);
    }
    memcpy(tempBuffer.mData, output, bufferList->mBuffers[0].mDataByteSize);
    

}

-(void) updatesnr{
    y=SNR_db;
    snrdisplay.text=[ NSString stringWithFormat:@"%f",y];
    
}
double expint_new(int n, double x)
{
    int i, ii, nm1;
    double a, b, c, d, del, fact, h, psi, ans;
    
    nm1 = n - 1;
    if (n < 0 || x < 0.0 || (x == 0.0 && (n == 0 || n == 1)))
        ans = 0;
    else {
        if (n == 0)
            ans = exp(-x) / x;
        else {
            if (x == 0.0)
                ans = 1.0 / nm1;
            
            else {
                if (x > 1.0) {
                    b = x + n;
                    c = 1.0 / FPMIN;
                    d = 1.0 / b;
                    h = d;
                    for (i = 1; i <= MAXIT; i++) {
                        a = -i*(nm1 + i);
                        b += 2.0;
                        d = 1.0 / (a*d + b);
                        c = b + a / c;
                        del = c*d;
                        h *= del;
                        if (fabs(del - 1.0) < EPS) {
                            ans = h*exp(-x);
                            return ans;
                        }
                    }
                }
                else {
                    ans = (nm1 != 0 ? 1.0 / nm1 : -log(x) - EULER);
                    fact = 1.0;
                    for (i = 1; i <= MAXIT; i++) {
                        fact *= -x / i;
                        if (i != nm1) del = -fact / (i - nm1);
                        else {
                            psi = -EULER;
                            for (ii = 1; ii <= nm1; ii++) psi += 1.0 / ii;
                            del = fact*(-log(x) + psi);
                        }
                        ans += del;
                        if (fabs(del) < fabs(ans)*EPS)
                            return ans;
                    }
                }
            }
        }
    }
    return ans;
}
- (IBAction)snr:(id)sender {
    [self updatesnr];
}

- (IBAction)buttonPressed:(id)sender {
    [self updateBeta1];
    
}

- (IBAction)SwitchPressed:(id)sender
{
    if(EnhancedSwitch.on)
    {
        on=1;
    }
    else
    {
        on=0;
    }
}

- (IBAction)betaValue:(id)sender {
    [self updateBeta];
}

- (IBAction)stepbeta:(id)sender {
    [self updateBeta];
}
- (IBAction)volumesliderAction:(id)sender
{
    [[MPMusicPlayerController applicationMusicPlayer] setVolume:self.volumeslider.value];
}

@end
