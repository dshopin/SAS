/** StackOverflow question on
http://stackoverflow.com/questions/21082649/defining-variables-in-one-table-based-on-values-in-another-table

Automatic creation of a new variable in DataTable fro each existing variable showing the ranges for each value of
the existing variable. Ranges are specific for each variable and given in another dataset Var_Groupings.
So the desired result will be:

Var001  Var002  Var001_Group  Var002_group
 000     050       0-25         31-50
 063     052       26-75        51-60
 015     017       0-25         0-30
 997     035       76-999       31-50
*/

Data DataTable;
Input Var001 $ Var002 $;
Datalines;
000 050
063 052
015 017
997 035
;
run;
Data Var_Groupings;
input var $ range $ Group_Desc $;
Datalines;
001 025 0-25
001 075 26-75
001 999 76-999
002 030 0-30
002 050 31-50
002 060 51-60
002 999 61-999
;
run;


/*create dataset which will be the source of our formats' descriptions*/
data formatset;
    set Var_Groupings;
    if _N_=1 then reg1=prxparse("/(\d+)-(\d+)/");
    retain reg1;
    fmtname='myformat';
    type='n';
    label=Group_Desc;
    if prxmatch(reg1,Group_Desc) then do;
        start=input(prxposn(reg1,1,Group_Desc),8.);
        end=input(prxposn(reg1,2,Group_Desc),8.);
    end;
    drop reg1 range;
run;

/*sort it by variable number*/
proc sort data=formatset; by var; run;

/*put the raw data into new one, which we'll change to get what we want (just to avoid 
 changing the raw one)*/
data want;
    set Datatable;
run;

/*now we iterate through all distinct variable numbers. A soon as we find new number
we generate with CALL EXECUTE three steps: PROC FORMAT, DATA-step to apply this format     
to a specific variable, and then PROC CATALOG to delete format*/
data _null_;
    set formatset;
    by var;
    if FIRST.var then do;
        call execute(cats("proc format library=work cntlin=formatset(where=(var='",var,"')); run;"));
        call execute("data want;");
        call execute("set want;");
        call execute(cats('_Var',var,'=input(var',var,',8.);'));
        call execute(cats('Var',var,'_Group=put(_Var',var,',myformat.);'));
        call execute("drop _:;");
        call execute("proc catalog catalog=work.formats; delete myformat.format; run;");
    end;
run;
