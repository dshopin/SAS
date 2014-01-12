/**********************************************************************************************************************************
MACRO for creating Excel-dictionary for a dataset
***********************************************************************************************************************************/
%macro XLSDictionary(
						outpath=,
						/*Path to the output location*/

						out=,
						/*Name of output xls-file*/

						data=,
						/*Input dataset*/

						categ=,
						/*numeric/date variables that should be summarized as categorical*/

						excl=
						/*variables that should be excluded*/

					);

proc format;
		picture mypct low-high='000,009.999%';
run;

%local dotpos dsn lib excl_r excl_q categ_r categ_q numbars datevars charvars;

/*Extracting library and dataset name for input data*/
%let dotpos=%index(&data,.)	;
%if &dotpos^=0 %then %do;
	%let dsn=%substr(&data,%eval(&dotpos+1),%eval(%length(&data)-&dotpos));
	%let lib=%substr(&data,1,%eval(&dotpos-1));
%end;
%else %do;
	%let dsn=&data;
	%let lib=WORK ;
%end;

/*If categ= and excl= values are range of variables with mask : (e.g. price: for price1, price2 etc)
then we separate them and delete :*/
%do i=1 %to %sysfunc(countw(&excl,%str( )));
	%let var=%scan(&excl,&i,%str( ));
	%if %index(&var,:)>0 %then %do;
		%if %symexist(excl_r) %then %let excl_r=&excl_r %substr(&var,1,%eval(%length(&var)-1));
		%else  %let excl_r=%substr(&var,1,%eval(%length(&var)-1));
	%end;
	%else %do;
		%if %symexist(excl_q) %then %let excl_q=&excl_q  &var;
		%else  %let excl_q=&var;
	%end;
%end;

%do i=1 %to %sysfunc(countw(&categ,%str( )));
	%let var= %scan(&categ,&i,	%str( ));
	%if %index(&var,:)>0 %then %do;
		%if %symexist(categ_r) %then %let categ_r=&categ_r %substr(&var,1,%eval(%length(&var)-1));
		%else  %let categ_r=%substr(&var,1,%eval(%length(&var)-1));
	%end;
	%else %do;
		%if %symexist(categ_q) %then %let categ_q=&categ_q  &var;
		%else  %let categ_q=&var;
	%end;
%end;



/*Adding quotes around variables that should be considered categorical (from &categ) or excluded
First, add quote in the start and end, then replacing blanks between values with quote-blank-quote
and then upcase-ing everything*/
%if %length(&categ_q)>0 %then %do;
	%let categ_q=%upcase(%sysfunc(transtrn(%str(%')&categ_q%str(%'),%str( ),%str(' '))));
%end;
%if %length(&excl_q)>0 %then %do;
	%let excl_q=%upcase(%sysfunc(transtrn(%str(%')&excl_q%str(%'),%str( ),%str(' '))));
%end;
%if %length(&categ_r)>0 %then %do;
	%let categ_r=%upcase(%sysfunc(transtrn(%str(%')&categ_r%str(%%%'),%str( ),%str(%%' '))));
%end;
%if %length(&excl_r)>0 %then %do;
	%let excl_r=%upcase(%sysfunc(transtrn(%str(%')&excl_r%str(%%%'),%str( ),%str(%%' '))));
%end;

%put %length(categ_q);

/*Getting numeric, date and character variables separately*/
proc sql noprint;
	select name into :numvars separated by ' '
	from sashelp.vcolumn
	where libname=upcase("&lib") and memname=upcase("&dsn")
		and	type='num' and format not like 'DATE%'
		%if %length(&categ_q)>0 or %length(&excl_q)>0 %then %do;
			and upcase(name) not in (&categ_q &excl_q)
		%end;

		%if %length(&categ_r)>0 %then %do;
			%do i=1 %to %sysfunc(countw(&categ_r,%str( )));
				and upcase(name) not like %scan(&categ_r,&i,%str( ))
			%end;
		%end;

		%if %length(&excl_r)>0 %then %do;
			%do i=1 %to %sysfunc(countw(&excl_r,%str( )));
				and upcase(name) not like %scan(&excl_r,&i,%str( ));
			%end;
		%end;
		;

	select name into :datevars separated by ' '
	from sashelp.vcolumn
	where libname=upcase("&lib") and memname=upcase("&dsn")
	and	type='num' and format like 'DATE%'
		%if %length(&categ_q)>0 or %length(&excl_q)>0 %then %do;
			and upcase(name) not in (&categ_q &excl_q)
		%end;

		%if %length(&categ_r)>0 %then %do;
			%do i=1 %to %sysfunc(countw(&categ_r,%str( )));
				and upcase(name) not like %scan(&categ_r,&i,%str( ))
			%end;
		%end;

		%if %length(&excl_r)>0 %then %do;
			%do i=1 %to %sysfunc(countw(&excl_r,%str( )));
				and upcase(name) not like %scan(&excl_r,&i,%str( ))
			%end;
		%end;
		;

	select name into :charvars separated by ' '
	from sashelp.vcolumn
	where libname=upcase("&lib") and memname=upcase("&dsn")
		and	
		(
		type='char' 
		%if %length(&categ_q)>0 %then %do;
			or upcase(name) in (&categ_q)
		%end;
		%if %length(&categ_r)>0 %then %do;
			%do i=1 %to %sysfunc(countw(&categ_r,%str( )));
				or upcase(name) like %scan(&categ_r,&i,%str( ))
			%end;
		%end;

		)
		%if %length(&excl_q)>0 %then %do;
			and upcase(name) not in (&excl_q)
		%end;
		%if %length(&excl_r)>0 %then %do;
			%do i=1 %to %sysfunc(countw(&excl_r,%str( )));
				and upcase(name) not like %scan(&excl_r,&i,%str( ))
			%end;
		%end;
		;
quit;


/*creating Excel-file*/
ods tagsets.excelxp path="&outpath"
					file="&out._%sysfunc(left(%sysfunc(date(),date9.))).xls"
					style=Printer;
ods select position;

ods tagsets.ExcelXP options(embedded_titles='yes'
							embedded_footnotes='yes' 
 							sheet_name='Data Dictionary'
							sheet_interval='none');
title "Data Dictionary for SAS table &dsn";
proc contents data=&data order=varnum; run;

ods tagsets.ExcelXP options(embedded_titles='yes'
							embedded_footnotes='yes' 
 							sheet_name='Summary Stats'
							Width_Fudge='1'
							Autofit_height='yes'
							sheet_interval='none');
title "Summary Statistics for SAS table &dsn";
options label=off;
%if %length(&datevars)>0 %then %do;
	title2 'Date variables';
	proc tabulate data=&data;
		var &datevars;
		table	&datevars
				,n nmiss (min q1 mean median q3 max)*f=date9.;
	run;
	title;
%end;
%if %length(&numvars)>0 %then %do;
	title2 "Numeric variables";
	proc tabulate data=&data;
		var  &numvars;
		table &numvars
				,n nmiss (min q1 mean median q3 max)*f=best12.;
	run;
	title;
%end;
                              
                                             
*formatting values in PROC FREQ output;

ODS PATH RESET;                              
ODS PATH (PREPEND) WORK.Templat(UPDATE) ;    
                                             
PROC TEMPLATE;                               
  EDIT Base.Freq.OneWayList;                 
    EDIT Frequency;                          
      FORMAT = COMMA6.;                      
    END;                                     
    EDIT Percent;                            
      FORMAT = mypct.;                          
    END;                                     
  END;                                       
RUN;        
%if %length(&charvars)>0 %then %do;
	title2 'Categorical variables';
	proc freq data=&data;
		tables	&charvars/ nocum missing;
	run;
	title;
%end;


ods tagsets.excelxp close;

title2;
options label=on;

PROC TEMPLATE;
delete Base.Freq.OneWayList;
run;

/******************************************
FORMATTING WITH DDE
*******************************************/

/*starting Excel*/
options noxsync noxwait;
filename sas2xl dde 'excel|system';

data _null_;
	length fid rc start stop time 8;
	fid=fopen('sas2xl','s');
	if (fid le 0) then do;
		rc=system('start excel');
		start=datetime();
		stop=start+10;
		do while (fid le 0);
			fid=fopen('sas2xl','s');
			time=datetime();
			if (time ge stop) then fid=1;
		end;
	end;
rc=fclose(fid);
run;

/*open workbook*/

data _null_;
	file sas2xl;
	put '[error(false)]';
	put "[open(""&outpath.\&out._%sysfunc(left(%sysfunc(date(),date9.))).xls"")]";
	put	'[column.width(0,"c1:c6",false,3)]';
	put	'[column.width(200,"c7")]';
	put '[select("r1c1")]';
	put '[format.font("Thorndale AMT",13,true,false,false,false,0,false,false)]';
	put '[workbook.activate("Summary Stats")]';
	put	'[column.width(0,"c1:c9",false,3)]';
	put '[select("r1c1")]';
	put '[format.font("Thorndale AMT",13,true,false,false,false,0,false,false)]';
	put '[workbook.activate("Data Dictionary")]';
	put '[save()]';
	put '[file.close(false)]';
run;

%mend;

/*Example of using*/
/*%XLSDictionary(*/
/*						outpath=C:\,*/
/**/
/*						out=test,*/
/*						/*Name of output xls-file*/*/
/**/
/*						data=sashelp.Pricedata,*/
/*						/*Dataset*/*/
/**/
/*						categ=price:,*/
/*						/*numeric/date variables that should be summarized as categorical*/*/
/**/
/*						excl=sale product: price*/
/*					)*/
