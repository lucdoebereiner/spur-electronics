/////// SPUR (2019)
/////// for cello, double bass and live electronics
/////// (c) 2019 by Luc Döbereiner
/////// luc.doebereiner@gmail.com


/////// Input 0 = Instrument 1
/////// Input 1 = Instrument 2

/////// Output 0 = to headphones of instrument 1
/////// Output 1 = to headphones of instrument 2
/////// Output 2 and 3 = Electronics via loudspeakers

/////// Midi Controller Numbers 1-6 are used


s.options.numOutputBusChannels = 8;
s.options.numInputBusChannels = 8;
s.options.memSize = 8192*8;
s.options.blockSize = 256;
s.reboot;
s.quit
// jack frame size 1024
s.meter;


(
SynthDef(\spur, { arg buf, amp = 0.1, nDiffFreqs=0, nVoices = 1,speed=1,pauses=3, thresh=0.3;
	var contrast, contrast2, whitened, whitened2, past, past2, peaks2,
	new, new2, ampSub, ampMul, peaks,rndPhase,lagged, chain, chain2,
	chainMul1, chainMul2, subtract1, subtract2, sumOut, shifted1, shifted2,
	mags1,mags2,analy1,analy2,subtractIfft, input, input1, input2, outElec1, outElec2,fftSize=2**14,
	freqs1, freqs2, out1, out2, amps, freqsDiff1, freqsDiff2, durFacs1, durFacs2;

	input = SoundIn.ar([0,1]);
	
	input1 = HPF.ar(input[0]*1.5,100)*3;
	input1 = Compander.ar(input1,input1, 0.1, 1, 0.1)*3;

	input2 = HPF.ar(input[1]*1.5,100)*3;
	input2 = Compander.ar(input2,input2, 0.1, 1, 0.1)*3;

	chain = FFT(LocalBuf(fftSize), HPF.ar(input1,100), 0.5);
	chain2 = FFT(LocalBuf(fftSize), HPF.ar(input2,100), 0.5);
	
	whitened = PV_Whiten(PV_Copy(chain, LocalBuf(fftSize)), LocalBuf(fftSize));
	whitened2 = PV_Whiten(PV_Copy(chain2, LocalBuf(fftSize)), LocalBuf(fftSize));
	contrast = PV_MagMul(chain,whitened);
	contrast2 = PV_MagMul(chain2,whitened2);


	past = PV_MagLagUD(PV_Copy(contrast, LocalBuf(fftSize)), 0.4, 6);
	past2 = PV_MagLagUD(PV_Copy(contrast2, LocalBuf(fftSize)), 0.4, 6);
	new = PV_MagMinus(PV_Copy(contrast, LocalBuf(fftSize)), past);
	new2 = PV_MagMinus(PV_Copy(contrast2, LocalBuf(fftSize)), past2);

	
	subtract1 = PV_MagMinusOct(PV_Copy(new2, LocalBuf(fftSize)),
		PV_Copy(new, LocalBuf(fftSize)));
	subtract2 = PV_MagMinusOct(PV_Copy(new, LocalBuf(fftSize)),
		PV_Copy(new2, LocalBuf(fftSize)));

	
	analy1 = MagPeaksFreqs.kr(subtract1,8,thresh.lag2(2));
	analy2 = MagPeaksFreqs.kr(subtract2,8,thresh.lag2(2));
	
	freqs1 = analy1[0..7];
	freqs2 = analy2[0..7];

	mags1 =  analy1[8..15].explin(15,400,0.25,1).lag2ud(0,3);
	mags2 =  analy2[8..15].explin(15,400,0.25,1).lag2ud(0,3);

	durFacs1 = mags1.linlin(0.25,1,0.75,1.5).lag2(3);
	durFacs2 = mags1.linlin(0.25,1,0.75,1.5).lag2(3);

	freqsDiff1 = freqs1 + freqs2;
	freqsDiff2 = (freqs2 - freqs1).abs;

	freqs1 = TWChoose.kr(Changed.kr(freqs1),[freqs1,freqsDiff1], [1-nDiffFreqs, nDiffFreqs]);
	freqs2 = TWChoose.kr(Changed.kr(freqs2),[freqs2,freqsDiff2], [1-nDiffFreqs, nDiffFreqs]);
	
	freqs1 = OnOffChange.kr(freqs1,mags1,([ 12, 10.6, 9.9, 8.5, 7.8, 6.4, 5.7, 5 ]!8)*speed*durFacs1.lag2(2),
		pauses.lag2(2));
	freqs2 = OnOffChange.kr(freqs2,mags2,([ 12, 10.6, 9.9, 8.5, 7.8, 6.4, 5.7, 5 ]!8)*speed*durFacs2.lag2(2),
		pauses.lag2(2));

	
	amps =  8.collect({ arg i; (i < nVoices).if(1,0) });

	out1 = Mix.ar( (SinOsc.ar(WrapOct.kr(freqs1[0].clip(10,25000)+Rand(-0.25,0.25!4), 180,780),
		Rand(0,6.0!4),freqs1[1]*0.2) * freqs1[0].clip(0,1).lag3(4) * amps.lag3(4) )  ) * 0.8;

	out2 = Mix.ar(SinOsc.ar(WrapOct.kr(freqs2[0].clip(10,25000)+Rand(-0.25,0.25!4), 180,780),
		Rand(0,6.0!4),freqs2[1]*0.2) * freqs2[0].clip(0,1).lag3(4) * amps.lag3(4) ) * 0.8;


	outElec1 = Mix.ar( (SinOsc.ar(WrapOct.kr(freqs1[0].clip(10,25000)+Rand(-0.25,0.25!4), 40, 9000),//180,780),
		Rand(0,6.0!4),freqs1[1]*0.2) * freqs1[0].clip(0,1).lag3(4) * amps.lag3(4) )  ) * 0.6;

	outElec2 = Mix.ar(SinOsc.ar(WrapOct.kr(freqs2[0].clip(10,25000)+Rand(-0.25,0.25!4), 40, 9000),//180,780),
		Rand(0,6.0!4),freqs2[1]*0.2) * freqs2[0].clip(0,1).lag3(4) * amps.lag3(4) ) * 0.6;

	
	Out.ar(0, out1);
	Out.ar(1, out2);

	Out.ar(2, [ outElec1, outElec2 ] * amp.lag2(0.3)  );
	
}).load(s)
)


(
// Evaluate once before starting the piece
ControlSpec.specs[\amp] = ControlSpec(0.0, 0.7, 1, 0.001, 0);
ControlSpec.specs[\nVoices] = ControlSpec(1, 8, 1, 1, 1);
ControlSpec.specs[\nDiffFreqs] = ControlSpec(0, 1, 1, 0.00001, 0);
ControlSpec.specs[\speed] = ControlSpec(0.5, 6, 2, 0.00001, 1);
ControlSpec.specs[\pauses] = ControlSpec(0.25, 12, 2, 0.00001, 3);
ControlSpec.specs[\thresh] = ControlSpec(0.01, 9, 2, 0.00001, 0.3);

~ampCtrl = Bus.control(s, 1).set(0.0);
~nVoicesCtrl = Bus.control(s, 1).set(1);
~nDiffFreqsCtrl = Bus.control(s, 1).set(0);
~speedCtrl = Bus.control(s, 1).set(1);
~pausesCtrl = Bus.control(s, 1).set(3);
~threshCtrl = Bus.control(s, 1).set(0.3);


MIDIIn.connectAll;

MIDIdef.cc(\amp, { arg v;
	~ampCtrl.set(ControlSpec.specs[\amp].map(v/127).postln)}, 1);

MIDIdef.cc(\nVoices, { arg v;
	~nVoicesCtrl.set(ControlSpec.specs[\nVoices].map(v/127).postln)}, 2);

MIDIdef.cc(\nDiffFreqs, { arg v;
	~nDiffFreqsCtrl.set(ControlSpec.specs[\nDiffFreqs].map(v/127).postln)}, 3);

MIDIdef.cc(\speed, { arg v;
	~speedCtrl.set(ControlSpec.specs[\speed].map(v/127).postln)}, 4);

MIDIdef.cc(\pauses, { arg v;
	~pausesCtrl.set(ControlSpec.specs[\pauses].map(v/127).postln)}, 5);

MIDIdef.cc(\thresh, { arg v;
	~threshCtrl.set(ControlSpec.specs[\thresh].map(v/127).postln)}, 6);


)



(
// Start once at the beginning of the piece
~synth = Synth(\spur, [\amp, ~ampCtrl.asMap, \nVoices,
~nVoicesCtrl.asMap, \speed, ~speedCtrl.asMap, \nDiffFreqs,
~nDiffFreqsCtrl.asMap, \pauses, ~pausesCtrl.asMap, \thresh, ~threshCtrl.asMap]);
)



//~synth.free;
