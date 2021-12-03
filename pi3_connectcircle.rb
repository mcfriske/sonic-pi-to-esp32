#testOscController.rb
#test OSC controller to adjust amp/reverb/pan/samplename
#written by Robin Newman, October 2019 to illustrate techniques
#
# NB switch OFF Enfore timing guarantees in the prefs Audio tab for this program to work
# It processes many OSC messages from slider inputs and needs some leeway to process them
#
#uses TouchOSC as input device, but should be modifiable for other OSC sources
#makes use of function parse_osc. This uses an undocumented internal function
#of Sonic Pi _event which returns full information on a given event
#Sonic Pi accepts wild cards when matching triggers from OSC messages.
#parse_osc lets you input the wild card string used, and from that to
#determine the actual OSC message which triggered the match.
#So using this you can use one live_loop to parse and deal with several similar
#events, such as those from sliders (three used here)
#or multiple switches (1 4 way togggle switch used here)
#I include a verbose version of parse_osc which prints out the data it is
#working with so you can follow the process,
#which involves Ruby string handling methods
#simply switch over which parse_osc version is uncommented to change them over
##| use_debug false
##| use_osc_logging false
##| use_cue_logging false
use_osc "128.138.103.126", 9000 #set ip and port of TouchOSC to receive messages

#comment out ONE of the two parse_osc definitions, quiet or verbose
define :parse_osc do | path | #quiet version
  v = get_event(path).to_s.split(",")[6]
  if v != nil
    return v[3..-2].split("/")
  else
    return ["Could not decipher osc path..."]
  end
end

##| define :parse_osc do |path| #verbose version
##|   puts "op1: #{get_event(path)}"
##|   puts "op2: #{get_event(path).to_s.split(",")}"
##|   v= get_event(path).to_s.split(",")[6]
##|   if v != nil
##|     puts "op3: #{v}"
##|     puts "op4: #{v[3..-2].split("/")}"
##|     return v[3..-2].split("/")
##|   else
##|     return ["error"]
##|   end
##| end

#function switches leds on TouchOSC on/off
define :ledSwitch do |n|
  in_thread do #run in a thread so as not to impact timings
    #leds named from 1-4, but indices go 0-3 so add 1 to x and n
    4.times do |x| #switch all leds off
      osc "/test/led/"+(x+1).to_s,0
    end
    sleep 0.05 #makes sure touchOSC has time to respond
    osc "/test/led/"+(n+1).to_s,1 #switch selected led on
  end
end

#setup list of samples to use
audio_sample = "/home/pi/Desktop/frogs.wav"
#set starting values
set :scurrent,audio_sample #initial sample
set :sIndex,2 #index of initial sample in list
set :rv,0 #initial reverb room: size
set :pan,0 #initial pan: setting
set :vol,0.5 #initial amp: setting

#send settings to sliders and switch to initialise

osc "/test/slider/vol",0.5
osc "/test/slider/pan",0
osc "/test/slider/reverb",0
osc "/test/sample/4/1",1 #switch in vertical row 1, position 1 set to on

#start fx reverb, wrapped round all sound generation
with_fx :reverb,room: get(:rv),mix: 0.7 do |r|
  #save pointer to fx reverb in :r
  set :r,r
  
  #loop to select current sample. (changes at end of current sample)
  ##| live_loop :sampleControl do
  ##|   use_real_time
  ##|   data = sync "/osc*/test/sample/*/*" #respond to any switch
  ##|   if data==[1.0] #just get data if pushed ie 1 #filter out all but switch "on"
  ##|     sn = parse_osc"/osc*/test/sample/*/*" #get actual switch pushed
  ##|     puts sn #show response from osc_parse
  ##|     #now choose 4th element and convert to integer. Subtract 1 to index from 0
  ##|     sn=sn[3].to_i - 1
  ##|     set :sIndex,sn #store sample index
  ##|     set :scurrent,slist[sn] #store current sample name
  ##|     puts get(:scurrent) #print current sample name selected
  ##|   end
  ##| end
  
  #loop to get and set slider data
  live_loop :sliders do
    use_real_time
    data = sync "/osc*/test/slider/*" #respond to all sliders
    slider=parse_osc  "/osc*/test/slider/*"
    puts slider #show response from parse_osc
    slider=slider[3]
    case slider
    when "vol"
      set :vol,data[0]
      puts get(:vol)
      control get(:sp),amp: 2 * get(:vol)
    when "reverb"
      set :rv,data[0]
      puts get(:rv)
      control get(:r),room: get(:rv)
    when "pan"
      set :pan,data[0]
      puts get(:pan)
      control get(:sp),pan: get(:pan)
    end
  end
  
  live_loop :playSample do
    #here I have used beat_stretch: opt to set all samples to 2 beats
    #however will work with any sample length
    sp=sample get(:scurrent) ,amp: 2 * get(:vol),pan: get(:pan),beat_stretch: 2
    set :sp,sp
    ledSwitch get(:sIndex) #switch led as sample starts playing
    #change following line to sample_duration get(:scurrent)
    #if not using beat_stretch
    sleep 2#sample_duration get(:scurrent)
  end
end #reverb