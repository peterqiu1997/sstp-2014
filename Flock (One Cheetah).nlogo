;PROBLEM WITH SWITCHING TARGETS?
;RANDOMIZE SPEEDS
;1050 - 1100 tick chase duration gives success rate ~50% WITH switching
;set at 1000 for now
;energy measured at kilocalories, not kilojoules
;springbok has 106 kilocalories per 100 grams?
;LIMIT AMOUNT OF MEAT CHEETAHS CAN EAT
;USING SPRINGBOK RIGHT NOW
;STALKSPEED

breed [cheetahs cheetah]
breed [gazelles gazelle]

globals [
  max-align-turn
  max-cohere-turn
  max-separate-turn
  avg-dist-trav
  
  ;booleans
  kpfactor
  chase?
  acquired?
  detected?
  maneuver?
  caught?
  already-switched?
  
  ;velocites/coordinates
  vcheetah
  targetgazelle
  maxvcheetah  
  basevgazelle
  herdcenterx
  herdcentery
  attackdistance        
  COMx                  
  COMy 
  hunted                 
  
  ;radii
  rdetection
  rcaught
  rbig
  rsmall
  rmaneuver
  rspawn
  varianceamp
  
  ;miscellaneous
  targetnumber
  mindist
  gravity
  chaseduration
  scale
  finalvision
  vision
  herdsize
  herdradius
  cheetahmaxturn
  total-energy
  
]

gazelles-own [
  mass
  energy-possessed
  vgazelle
  maxvgazelle
  targetx
  targety
  phi
  flockmates 
  nearest-neighbor
]

cheetahs-own [
  distance-covered
  stalk-time
  energy-expended
  distance-travelled
  mass
]

;_________________________________________________________________________________________Setup and Go________________________________________________________________________________

to setup
  ca
  
  set kpfactor random(100) + 1
  ifelse kpfactor <= 12 [set kpfactor true][set kpfactor false]
  set max-align-turn 0.6
  set max-cohere-turn 0.8
  set max-separate-turn 0.3
 ; set detection-chance random(100) + 1
  set-default-shape links "arrow" 
  set-default-shape gazelles "dot"
  set-default-shape cheetahs "default"
  
  ;radii and velocities
;  ifelse(detection-chance / 100 > 0.2) 
;  [set detected? false]
;  [set detected? true]
  set rdetection 30
  set rspawn 37
  set attackdistance 30
  set rcaught 1
  set rsmall 4
  set rbig 7
  set rmaneuver 12
  set basevgazelle 7
  set vcheetah vprowl
  set maxvcheetah 24
  
  
  ;numeric variables
  set gravity 9.8
  set varianceamp 90
  set scale 100  
  set vision 20
  set herdsize 10
  set herdradius 6
  set chaseduration 1000
  
  ;booleans
  set already-switched? false
  set caught? false
  set acquired? false
  set chase? false
  set maneuver? false
  set detected? false
  
  ask patches [ set pcolor green - 2]
  
  create-cheetahs 1 [
    set color red
    set size 2
    set mass 40 + random(10) - 5
    set xcor rspawn * cos(init-angle)
    set ycor rspawn * sin(init-angle)
    set heading towardsxy 0 0 
    pendown
  ]  
  
  create-gazelles herdsize [ 
;;;;yet to be implemented    
;    ifelse(prey-size-chance < 2)
;    [;set mass large
;      ;set mass random(105) + 65
;    ]
;    [ifelse(prey-size-chance < 20)
;      [;set prey small
;      ]
;      [;set prey medium
;      ]
;    ]
    set mass 40 + random(20) - 10
    set maxvgazelle 16 + random(2) - 1
    set vgazelle 2
    set color white
    set size 2
    set herdcenterx (random (2 * herdradius) - herdradius)
    set herdcentery (random (2 * herdradius) - herdradius)
    set xcor herdcenterx
    set ycor herdcentery
    set heading (towards cheetah 0 + 180) + random(180) - 90
  ]
  reset-ticks
end

to go
  every timescale(1) [ 
    set cheetahmaxturn calccheetahmaxturn
    findCOM  
    adjustvelocity
    
    ask cheetahs [       
      acquiretarget  
      move-to-prey
      updatetarget   
      checkcaught
    ]
    
    ask gazelles [ 
      fd timescale(vgazelle)
      check-maneuver
      if (chase? or detected?) [                                                                                                   
        if(distance pursuer < (rdetection - 3) and not(who = targetnumber))        ;run straight ahead unless cheetah gets too close
        [disperse]    
        accelerategazelle (4)
      ]
      ifelse(who = targetnumber and maneuver?)    
        [maneuver] 
        [flock]
    ]
    
    if (caught?) [
      set hunted 1 
      ask cheetahs [total-energy-expended]
      print (word "Hunt successful! Net energy change: " total-energy " kcal.")
      print (word "Distance travelled: " dist?)
      stop
    ]  
    if (ticks > chaseduration) [ 
      set hunted 0 
      ask cheetahs [total-energy-expended]
      print (word "Hunt failed. Net energy change: " total-energy " kcal.")
      print (word "Distance travelled: " dist?)
      stop ]
    
    tick
  ]
  
end

;________________________________________________________________________________Energetics_____________________________________________________________________________________________________


to-report hunt?
  report hunted
end

to-report total-energy?
  report total-energy
end

to-report dist?
  set avg-dist-trav [distance-covered] of cheetah 0 
  report avg-dist-trav
end

to-report to-hour [input]
  report input / 360000
end

to-report kilograms-to-kilocalories [input]
  report input * 1500 ;106 kcal in 100g of springbok
end

to-report hunting-energy 
  report 78.3 * (mass ^ 0.84) * (to-hour (ticks) + 15 / 3600) ;aldama/calder equations
end

to-report stalk-energy 
  report 5.8 * (mass ^ 0.75) * (positioning-time) + 2.6 * (mass ^ 0.6) * (positioning-time * vprowl) ;aldama/calder equations
end

to-report look-energy
  report 5.8 * (mass ^ 0.75) * (look-time) + 2.6 * (mass ^ 0.6) * (look-time * 2)
end

to total-energy-expended
  let kgmeat [mass] of targetgazelle * percent-eaten ([mass] of targetgazelle)
  ifelse (caught? and not(kpfactor)) ;kleptoparasitism factor
  
  [  ifelse kgmeat > 7
    [set energy-expended (- hunting-energy - stalk-energy - look-energy) + 
      kilograms-to-kilocalories (7)]
    [set energy-expended (- hunting-energy - stalk-energy - look-energy) + 
      kilograms-to-kilocalories (kgmeat)] ]
  
  [ set energy-expended (- hunting-energy - stalk-energy - look-energy)]
  
  set total-energy total-energy + energy-expended
end

;;;;;;;;;;;
;;CHEETAH;;
;;;;;;;;;;;

to move-to-prey
  ifelse(acquired?)
  [
    turn-towards (towards gazelle targetnumber) cheetahmaxturn
  ask targetgazelle [ set color 85 pendown]
  set chase? true
  ]
  [set heading (towardsxy COMx COMy)]
  
  ifelse chase? [
    let old-xcor xcor let old-ycor ycor
    fd timescale(vcheetah)
    set distance-covered distance-covered + distancexy old-xcor old-ycor
  ] 
  [fd timescale(vprowl)]
end

to acquiretarget   
  if( (not(acquired?) and (distancexy COMx COMy < attackdistance or detected?) ) ) 
    [                                                                         
      set targetgazelle closest gazelles                                                                
      set targetnumber [who] of targetgazelle
      set mindist (distance targetgazelle)
      set acquired? true
    ]
  if(switch?) [
    if (acquired? and ticks < 1000 and not(already-switched?)) [
      ask gazelles in-cone 10 210 ;cheetah field of vision is 210 degrees
      [ if not(who = targetnumber) [
        ask links [die]
        set targetgazelle closest gazelles
        set targetnumber [who] of targetgazelle
        set already-switched? true
      ] 
      ]
    ]
  ]
end

to updatetarget
  if(acquired?)
  [create-link-with gazelle targetnumber]
end

to checkcaught
  if (acquired? and distance targetgazelle < rcaught) [set caught? true]
end

to accelerate [a]
  set (vcheetah) (vcheetah + timescale(a))
end


to decelerate [a]
  set (vcheetah) (vcheetah - timescale(a))
end


;;__________________________________________________________________________________________GAZELLE_________________________________________________________________________________;;

to check-maneuver
  if(acquired?)[
    ask gazelle targetnumber [
      ifelse (distance pursuer < rmaneuver) 
      [set maneuver? true]
      [set maneuver? false]
    ]
  ]
end

to maneuver
  wandersteer (vgazelle) (gazellemaxturn)
end

to-report detectionfxn [x]
  report ifelse-value (1 / (x - rdetection) > 1) 
  [1] [
    ifelse-value (1 / (x - rdetection) < 0) 
    [1] [1 / (x - rdetection)]
  ]
end

to detectionchance
  if (detectionfxn (distance pursuer) = 1) [set detected? true]
end

to-report pursuer
  report closest cheetahs
end

to accelerategazelle [a]
  set (vgazelle) (vgazelle + timescale(a))
end


to decelerategazelle [a]
  set (vgazelle) (vgazelle - timescale(a))
end

to-report percent-eaten [input-mass]
  ifelse(input-mass < 5) 
  [report 0.99] 
  [ifelse input-mass < 40 
    [report 0.90]
    [ifelse input-mass < 80 [
      report 0.75] [
    report 0.67] 
    ] 
  ]
end

;;;;;;;;;;;;;;;;
;;WANDER STEER;; ;;juking;;
;;;;;;;;;;;;;;;;


to wandersteer [v maxturn]
  phistuff
  updatetargetpos
  turn-towards (towardsxy targetx targety) maxturn
end  


to updatetargetpos
  set targetx xcor + rbig * cos (heading-to-angle (heading)) + rsmall * cos (phi)
  set targety ycor + rbig * sin (heading-to-angle (heading)) + rsmall * sin (phi)
end


to phistuff
  refreshphi
  checkphi
end


to refreshphi
  set phi phi + random (2 * varianceamp) - varianceamp
end


to checkphi
  if phi < 0 [set phi phi + 360]
  if phi > 360 [set phi phi mod 360]
end


;;;___________________________________________________________________________________Flocking____________________________________________________________________________________;;;


to flock  ;; gazelle flocking
  if(not detected?)
  [detectionchance]
  find-flockmates
  if any? flockmates
    [ find-nearest-neighbor
      ifelse (distance nearest-neighbor < minimum-separation)
        [ separate ]
        [ 
          align
          cohere
        ] 
    ]
  
end

to find-flockmates
  set flockmates other gazelles in-radius vision
end

to find-nearest-neighbor 
  set nearest-neighbor min-one-of flockmates [distance myself]
end

;;;;;;;;;;;;
;;DISPERSE;; ;;;has tendency to compress in front of predator;;;
;;;;;;;;;;;;

to disperse
  turn-towards (calc-away-heading) gazellemaxturn
end

to-report calc-away-heading
  ifelse(xcor > -100 and xcor < 100 and ycor > -100 and ycor < 100)
    [report atan (xcor - [xcor] of pursuer) (ycor - [ycor] of pursuer)]  
    [report (towards pursuer )                                                  
    ]
end


;;;;;;;;;
;;ALIGN;;
;;;;;;;;;


to align  
  turn-towards average-flockmate-heading max-align-turn
end

to-report average-flockmate-heading  ;; find arctangent of coordinates since headings are 1-359 not 0-180
  let x-component sum [dx] of flockmates
  let y-component sum [dy] of flockmates
  ifelse x-component = 0 and y-component = 0
    [ report heading ]
    [ report atan x-component y-component ]
end


;;;;;;;;;;
;;COHERE;;
;;;;;;;;;;


to cohere  
  turn-towards average-heading-towards-flockmates max-cohere-turn
end

to-report average-heading-towards-flockmates  
  ;add 180 to get heading towards *other* turtles, not from other turtles to myself
  let x-component mean [sin (towards myself + 180)] of flockmates
  let y-component mean [cos (towards myself + 180)] of flockmates
  ifelse x-component = 0 and y-component = 0
    [ report heading ]
    [ report atan x-component y-component ]
end

;;;;;;;;;;;;
;;SEPARATE;;
;;;;;;;;;;;;


to separate  
  turn-away ([heading] of nearest-neighbor) max-separate-turn
end

;____________________________________________________________________________________Helper Methods___________________________________________________________________________________

to adjustvelocity   
  ifelse maneuver? [decelerate 4] [if chase? [accelerate 3]]
  ask cheetahs [
    if (acquired?) [
      if vcheetah < [vgazelle] of targetgazelle [
        set (vcheetah) ([vgazelle] of targetgazelle + 2.5)]
    ]
  ]
  if vcheetah > maxvcheetah [set (vcheetah) (maxvcheetah)]
  ask gazelles [  if vgazelle > maxvgazelle [set (vgazelle) (maxvgazelle)] ]
end

to-report max-lat-accel
  ifelse(gravity * frictioncoefficient <= 13)
  [report gravity * frictioncoefficient]
  [report 13]
end

to-report calccheetahmaxturn
  report (max-lat-accel / vcheetah)
end

to-report closest [things]
  report min-one-of things [distance myself]
end

to findCOM
  set COMx ((sum [xcor] of gazelles) / herdsize)
  set COMy ((sum [ycor] of gazelles) / herdsize)
end

to turn-towards [new-heading max-turn]  
  turn-at-most (subtract-headings new-heading heading) max-turn
end

to turn-away [new-heading max-turn]
  turn-at-most (subtract-headings heading new-heading) max-turn
end


to turn-at-most [angle maxangle]
  ifelse (abs (angle) > maxangle) [                                                                     
    ifelse (angle < 0)
      [rt ( - maxangle)]
      [rt (   maxangle)]
  ]
  [rt angle]
end

to-report timescale [x] 
  report x / scale
end

to-report heading-to-angle [h]
  report (90 - h) mod 360
end
@#$#@#$#@
GRAPHICS-WINDOW
207
10
920
744
100
100
3.5
1
10
1
1
1
0
1
1
1
-100
100
-100
100
0
0
1
ticks
30.0

BUTTON
15
68
78
101
NIL
setup
NIL
1
T
OBSERVER
NIL
Q
NIL
NIL
1

BUTTON
122
66
185
99
NIL
go
T
1
T
OBSERVER
NIL
W
NIL
NIL
0

SLIDER
17
224
189
257
vprowl
vprowl
0
15
7
1
1
NIL
HORIZONTAL

SLIDER
19
297
191
330
minimum-separation
minimum-separation
0
3
1.1
0.05
1
NIL
HORIZONTAL

SLIDER
18
260
190
293
gazellemaxturn
gazellemaxturn
0
4
2.1
0.01
1
NIL
HORIZONTAL

PLOT
921
10
1219
400
velocity
time
cheetah velocity
0.0
30.0
0.0
30.0
true
false
"" ""
PENS
"default" 1.0 0 -11033397 true "" "if(ticks mod 10 = 0) [ask cheetah 0 [plot vcheetah]]"

SLIDER
17
185
189
218
frictioncoefficient
frictioncoefficient
0
2.0
1.3
0.1
1
NIL
HORIZONTAL

PLOT
921
399
1218
744
maximum angular velocity
time
angle
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "if ticks mod 10 = 0 [ ask cheetahs[plot cheetahmaxturn] ]"

SWITCH
20
374
123
407
switch?
switch?
1
1
-1000

MONITOR
38
450
166
495
extra tick counter
ticks
17
1
11

SLIDER
19
334
191
367
positioning-time
positioning-time
0.5
2
1.5
0.5
1
NIL
HORIZONTAL

INPUTBOX
130
375
190
435
init-angle
120
1
0
Number

SLIDER
17
142
189
175
look-time
look-time
0.1
1
0.5
0.1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.5
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Energetics + Success + Average chase Distance" repetitions="80" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>hunt?</metric>
    <metric>total-energy?</metric>
    <metric>dist?</metric>
    <enumeratedValueSet variable="switch?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frictioncoefficient">
      <value value="1.3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="vary friction" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>hunt?</metric>
    <metric>total-energy?</metric>
    <metric>dist?</metric>
    <enumeratedValueSet variable="frictioncoefficient">
      <value value="0.9"/>
      <value value="1.1"/>
      <value value="1.3"/>
      <value value="1.5"/>
      <value value="1.7"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Target Switch" repetitions="80" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>hunt?</metric>
    <metric>total-energy?</metric>
    <metric>dist?</metric>
    <enumeratedValueSet variable="switch?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frictioncoefficient">
      <value value="1.3"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

arrow
0.0
-0.2 0 0.0 1.0
0.0 1 2.0 2.0
0.2 0 0.0 1.0
link direction
true
0
Line -11221820 false 150 150 90 180
Line -11221820 false 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
