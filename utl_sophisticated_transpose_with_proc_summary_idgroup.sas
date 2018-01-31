Sophisticated transpose with proc summary idgroup

This is a transpose that 'proc transpose cannot do directly?'
I am not interested in the report, I want the fat output dataset.

Great Question

for gather macro see
Alea Iacta
https://github.com/clindocu/sas-macros-r-functions

This has applications?

  Four solutions

   1, Hardcoding
   2, No hardcoding
   3. utl_gather macro
   4. Related applications of proc summary idgroup (data _null_ and fried egg?)
   5. Where proc corresp fits in (summary can not sort-transpose-and-summarize)
   6. proc report fits in

see
https://goo.gl/8mF5mJ
https://communities.sas.com/t5/Base-SAS-Programming/Creating-changing-variable-names-within-do-loop/m-p/432026

KSharp profile
https://communities.sas.com/t5/user/viewprofilepage/user-id/18408

MAKE INPUT
==========

data have;
input group pay taxes net ;
cards4;
1 1 100 200
1 4 110 150
1 3 120 300
2 7 105 .
;;;;
run;quit;

INPUT
=====

  WORK.HAVE total obs=4

    GROUP    PAY    TAXES    NET

      1       1      100     200
      1       4      110     150
      1       3      120     300

      2       7      105       .


  ALGORITHM
      1. Obtain the size of the maximum group ( 3 here )
      2. Transpose using suffixes of 1 to 3 within each group

         Group  PAY1  TAXES1  NET1 |  PAY2  TAXES2  NET2 |  PAY3  TAXES3  NET3
           1     1     100    200  |   4     110    150  |   3      120    300
           2     7     105     .   |   ,      ,      ,   |   .       .      .

PROCESES (All the code)
========================

1. HARDCODING  (full code)
=========================

   proc sql noprint;
   select max(n) into : n
    from (select count(*) as n from have group by group);
   quit;

   proc summary data=have;
   by group;
   output out=want (drop=_type_ rename=_freq_=count) idgroup(out[&n] (pay taxes net)=);
   run;quit;


2. NO HARDCODING (but does require grouping variable be character and other columns numeric)
   ==========================================================================================

   %symdel group pay taxes net / nowarn; * not needed - for QC only;
   data _null_;

     if _n_=0 then do;
       %let rc=sysfunc(dosubl('
          * this can be very slow;
          proc sql ;
          select name into :by separated by " " from sashelp.vcolumn
            where libname="WORK" and type="char" and memname="HAVE";
          select max(n) into : n
           from (select count(*) as n from have group by &by);
          select name into :vars separated by " " from sashelp.vcolumn
            where libname="WORK" and type="num" and memname="HAVE"
          ;quit;
      '));
     end;

     rc=dosubl('
        proc summary data=have;
        by &by.;
        output out=want (drop=_type_ rename=_freq_=count)
             idgroup(out[&n.] (&vars.)=);
        run;quit;
     ');

    stop;
   run;quit;


3. UTL_GATHER MACRO
===================

  * transpose can not do this?;
  %utl_gather(have,var,val,group,havXpo,valformat=4.);

  /* output of gather */
  WORK.HAVXPO total obs=12

   GROUP     VAR     VAL

     1      PAY        1
     1      TAXES    100
     1      NET      200
     1      PAY        2
     1      TAXES    110
     1      NET      150
     1      PAY        3
     1      TAXES    120
     1      NET      300
     2      PAY        4
     2      TAXES    105
     2      NET        .

  * Apply suffixes;
  data havFix;
    retain sfx 0; * even though not needed I like to declare it;
    length var $32;
    set havXpo;
    by group;
    if not last.group then do;
      if var='PAY' then sfx=sfx+1;
    end;
    var=cats(var,put(sfx,5.));
    if last.group then sfx=0;
  run;quit;

  proc transpose data=havFix out=havXpo(drop=_name_);
    by group;
    id var;
    var val;
  run;quit;


  WORK.HAVXPO total obs=2

  GROUP    PAY1    TAXES1    NET1    PAY2    TAXES2    NET2    PAY3    TAXES3    NET3

    1        1       100      200      2       110      150      3       120      300
    2        4       105        .      .         .        .      .         .        .


4. Related application of proc summary idgroup (data _null_ and fried egg?)
===========================================================================

   Min Max average for character and numeric variables

   github
   https://gist.github.com/rogerjdeangelis/d30e2bbcc42c799afce87f90afd39187

   see
   https://goo.gl/AGGAjw
   https://communities.sas.com/t5/Base-SAS-Programming/beginner-needs-help-with-min-max-function/m-p/426077

   proc summary data=sashelp.class nway;
      class sex;
      var _numeric_;
      output out=stats(drop=_freq_ _type_)
         n= min= max= mean=
         idgroup(min(sex) out(sex)=Sex_Min)
         idgroup(max(sex) out(sex)=Sex_Max)
         idgroup(min(name) out(name)=Name_Min)
         idgroup(max(name) out(name)=Name_Max)
         / autoname;
      run;

   proc print;
   run;
                                                 HEIGHT_  WEIGHT_           HEIGHT_  WEIGHT_
   Obs  SEX  AGE_N  HEIGHT_N  WEIGHT_N  AGE_MIN    MIN      MIN    AGE_MAX    MAX      MAX

    1    F      9       9         9        11      51.3     50.5      15      66.5    112.5
    2    M     10      10        10        11      57.3     83.0      16      72.0    150.0


                    HEIGHT_  WEIGHT_
   Obs    AGE_MEAN    MEAN     MEAN   SEX_MIN  SEX_MAX  NAME_MIN  NAME_MAX

    1      13.2222  60.5889   90.111     F        F      Alice    Mary
    2      13.4000  63.9100  108.950     M        M      Alfred   William


5. proc corresp and proc summary
================================

ods exclude all;
ods output observed=want;
proc corresp data=sashelp.class dim=1 observed;
tables sex, age;
run;quit;
ods select all;

* you cannot do this with a single 'proc summary';

Up to 40 obs WORK.WANT total obs=3

                    COUNTS (Ages in sashelp.class)

  LABEL    _11    _12    _13    _14    _15    _16    SUM

   F        1      2      2      2      2      0       9
   M        1      3      1      2      2      1      10
   Sum      2      5      3      4      4      1      19


6. proc report
==============
* you need macro below;

proc report data=sashelp.class
     nowd missing      /* CALLING RENAME MACRO */
     out=rptXpo (rename=(%utl_rptRen(sashelp.class,age)) drop=_break_);
 cols sex age, N;
 define sex / group "year" width=12;
 define age / group across "" width=12;
 run;quit;

%symdel nams / nowarn;
%macro utl_rptRen(nrm,acx);
%let nams=;
%let rc=
 %sysfunc(dosubl('
   %symdel nams / nowarn;
   proc sql;
     select cats("_C",put(monotonic()+1,1.),"_ =_",lon) into :nams separated by " "
     from
      (select distinct &acx as lon length=5 from &nrm)
   ;quit;
   '));
   &nams
%mend utl_rptRen;


4755   proc report data=sashelp.class
4756        nowd missing      /* CALLING RENAME MACRO */
4757        out=rptXpo
MLOGIC(UTL_RPTREN):  Beginning execution.
SYMBOLGEN:  Macro variable ACX resolves to age
SYMBOLGEN:  Macro variable NRM resolves to sashelp.class
NOTE: PROCEDURE SQL used (Total process time):
      real time           0.04 seconds
      user cpu time       0.03 seconds
      system cpu time     0.01 seconds
      memory              3743.73k
      OS Memory           23024.00k
      Timestamp           01/30/2018 09:04:35 PM
      Step Count                        1027  Switch Count  0


4757 !                 (rename=(%utl_rptRen(sashelp.class,age)) drop=_break_);
MLOGIC(UTL_RPTREN):  Parameter NRM has value sashelp.class
MLOGIC(UTL_RPTREN):  Parameter ACX has value age
MLOGIC(UTL_RPTREN):  %LET (variable name is NAMS)
MLOGIC(UTL_RPTREN):  %LET (variable name is RC)
SYMBOLGEN:  Macro variable NAMS resolves to _C2_ =_11 _C3_ =_12 _C4_ =_13 _C5_ =_14 _C6_ =_15 _C7_ =_16
MLOGIC(UTL_RPTREN):  Ending execution.
MPRINT(UTL_RPTREN):  _C2_ =_11 _C3_ =_12 _C4_ =_13 _C5_ =_14 _C6_ =_15 _C7_ =_16
4758    cols sex age, N;
4759    define sex / group "year" width=12;
4760    define age / group across "" width=12;
4761    run;

NOTE: There were 19 observations read from the data set SASHELP.CLASS.
NOTE: The data set WORK.RPTXPO has 2 observations and 7 variables.
NOTE: PROCEDURE REPORT used (Total process time):
      real time           0.16 seconds


