/************************************************************************
  Macro below downloads zip files from specific URL,using proc http and 
  stores them in an assigned directory with selected output file names.
 ************************************************************************/

%MACRO download_zip_files;
%Let file2 = "http://www.flcdatacenter.com/download/H1B_efile_FY02_text.zip" ;
%Let file3 = "http://www.flcdatacenter.com/download/H1B_efile_FY03_text.zip" ;
%Let file4 = "http://www.flcdatacenter.com/download/H1B_efile_FY04_text.zip" ;
%Let file5 = "http://www.flcdatacenter.com/download/H1B_efile_FY05_text.zip" ;
%Let file6 = "http://www.flcdatacenter.com/download/H1B_efile_FY06_text.zip" ;
%Let file7 = "http://www.flcdatacenter.com/download/H1B_efile_FY07_text.zip" ;
%Let DIM_file = 7;

%Let VAR2 = "C:\Users\adhikas\Desktop\GroupProject\IndividualProject\H1B_efile_FY02_text.zip" ;
%Let VAR3 = "C:\Users\adhikas\Desktop\GroupProject\IndividualProject\H1B_efile_FY03_text.zip" ;
%Let VAR4 = "C:\Users\adhikas\Desktop\GroupProject\IndividualProject\H1B_efile_FY04_text.zip" ;
%Let VAR5 = "C:\Users\adhikas\Desktop\GroupProject\IndividualProject\H1B_efile_FY05_text.zip" ;
%Let VAR6 = "C:\Users\adhikas\Desktop\GroupProject\IndividualProject\H1B_efile_FY06_text.zip" ;
%Let VAR7 = "C:\Users\adhikas\Desktop\GroupProject\IndividualProject\H1B_efile_FY07_text.zip" ;
%Let VAR_file = 7;

%DO I = 2 %TO &DIM_file;
	filename fhlmc &&VAR&I. ;

proc http
 	method='GET'
 	url=&&file&I.
 	out= fhlmc;
run;
%END;

%mend download_zip_files;
%download_zip_files


/************************************************************************
 Macro insizezip reads the content of the the zip files downloaded above.
 ************************************************************************/
%macro insidezip;

%DO I = 2 %TO &VAR_file;
  filename inzip zip &&VAR&I.;
  data zipfile_contents(keep=filename);
  fid=dopen("inzip"); /*Opens a directory and returns a directory identifier 
                          value.*/
  if fid=0 then stop;
      totalfile=dnum(fid); /*highest possible  member number that can be passed 
                            to DREAD */
  do i=1 to totalfile; /*loopint through 1 to totalfile */
    	  filename=dread(fid,i);
  	  output;
  end;
  rc=dclose(fid); /*closing the directory opened by dopen*/
run;


title &&VAR&I.;
proc print data =zipfile_contents;
run;

%END;

%mend insidezip;
%insidezip


/************************************************************************
 Using X command contacting windows command prompt and unzipping files
 ************************************************************************/
data _null_;
    X 'C:\art\7za.exe 
    e "C:\Users\adhikas\Desktop\GroupProject\IndividualProject\*.zip"
       -oC:\Users\adhikas\Desktop\GroupProject\IndividualProject';
run;

/************************************************************************
 Making use of macro to read data
 ************************************************************************/

data _null_;
/* Renaming 2007 data file in apporpriate format for batch reading using
   X command*/
options noxwait;
	x 'cd C:\Users\adhikas\Desktop\GroupProject\IndividualProject';
	x 'ren EFILE_FY2007*.txt H1B_efile_FY07*.txt';
run;

libname mydata  "C:\Users\adhikas\Desktop\GroupProject\IndividualProject";

%macro readallfiles;

%Let readfile2 = "C:\Users\adhikas\Desktop\GroupProject\IndividualProject\H1B_efile_FY02.txt" ;
%Let readfile3 = "C:\Users\adhikas\Desktop\GroupProject\IndividualProject\H1B_efile_FY03.txt" ;
%Let readfile4 = "C:\Users\adhikas\Desktop\GroupProject\IndividualProject\H1B_efile_FY04.txt" ;
%Let readfile5 = "C:\Users\adhikas\Desktop\GroupProject\IndividualProject\H1B_efile_FY05.txt" ;
%Let readfile6 = "C:\Users\adhikas\Desktop\GroupProject\IndividualProject\H1B_efile_FY06.txt" ;
%Let readfile7 = "C:\Users\adhikas\Desktop\GroupProject\IndividualProject\H1B_efile_FY07.txt" ;
%Let Dim_readfile = 7;

options spool;
%do I=2 %to &Dim_readfile;
  proc import datafile= &&readfile&I. dbms=CSV REPLACE
  out= mydata.fy&I;
  getnames=YES; 
  datarow=2;	 
run;
%end;

%mend readallfiles;
%readallfiles

/*Bringing 2007 data seperately in */
proc import datafile= "C:\Users\adhikas\Desktop\GroupProject\IndividualProject\H1B_efile_FY07.txt" 
  dbms=CSV REPLACE
  out= mydata.fy7;
  getnames=YES;
  datarow=2;	 
run;

/*Changing the visa code in 2007 data set*/
data fy7 ;
  length program_designation1 $20; 
  set mydata.fy7;	
  if program_designation = "." then delete;
  if program_designation = "R" then program_designation1="H1-B";
  if program_designation = "A" then program_designation1="E-3 Australian";
  if program_designation = "C" then program_designation1="H-1B1 Chile";
  if program_designation = "S" then program_designation1="H-1B1 Singapore";
  drop program_designation;	
run;

/*Dataset from year 2007 is ignored. The columns are named differently and had one extra column*/
proc sql;
  create table mydata.merged_dataset as (
  select *from mydata.fy2
  union all
  select *from mydata.fy3
  union all
  select *from mydata.fy4
  union all
  select *from mydata.fy5
  union all
  select *from mydata.fy6);
quit;

/*Creating relevant dataset table with variables of interest */
proc sql;
  create table mydata.pre_relevant_dataset as(
  select Name, Job_title,  Job_code, state, city,  Wage_rate_1,Rate_per_1, 
  nbr_immigrants, approval_status
  from mydata.merged_dataset);
quit;

/*Finding the data types of variables */
proc sql;
	describe table mydata.final_dataset;
run;
 
data mydata.relevant_dataset;
  set mydata.pre_relevant_dataset;
  if Name = 'Manhattan' or Name =  'New York' then delete;
  if wage_rate_1 = . then wage_rate_1=0 ;
  if job_code = . then job_code = 0; 
  if nbr_immigrants = . then nbr_immigrants =0;/*Normalizing Salary to year */
  if rate_per_1 = 'Year' then wage_rate_1 = wage_rate_1 ;
  else if rate_per_1 = 'Month' then wage_rate_1 = wage_rate_1*12;
  else if rate_per_1 = '2 Week' then wage_rate_1 = wage_rate_1*52/2;
  else if rate_per_1 = 'Week' then wage_rate_1 = wage_rate_1*52;
  else if rate_per_1 = 'Hour' then wage_rate_1 = wage_rate_1*52*40;
  employer1 = compress(Name,' '); /*compressing space characters*/
  employer = compress(employer1, '.');
  city    = propcase(City);
  drop Name;
  occupation = propcase(job_title);
  drop job_title;
  if wage_rate_1 >=1000000 then wage_rate_1=0; /* Spanish teacher making over a million*/
run;


/*Changing character variables to numeric for further manipulation*/

proc sql noprint;
  create table mydata.final_dataset as(
  select employer, occupation, state,city, approval_status,
 	   input(Job_code,2.) as job_code, 
	   wage_rate_1,rate_per_1,
	   input(nbr_immigrants, 4.) as nbr_immigrants
  from mydata.relevant_dataset);
quit;

ods rtf file = "C:\Users\adhikas\Desktop\GroupProject\IndividualProject\all.rtf" bodytitle style= journal;
/*Top and worst states with job openings for foreign nationals*/
proc sql ;
create table mydata.top10_states as 
  select state, sum(nbr_immigrants) as job_openings
  from mydata.final_dataset
  group by state
  order by job_openings desc;
quit;

title "Top states with job openings for foreign workers " ;
title2 "Table 1.1 " ;
proc print data = mydata.top10_states (obs = 50); /*limiting to USA only*/
run;

/*Top 10 cities along with their states with highest job openings for foreign nationals*/
title "Top 10 cities with their state names with highest job openings";
title2 "Table 1.2 " ;
proc sql outobs=10;
  select state,city, sum(nbr_immigrants) as job_openings
  from mydata.final_dataset
  where state IN (select state from mydata.top10_states)
  group by state,city
  order by job_openings desc;
quit;

/*Top 10 jobs in demand and their average salaries*/
title "Top 10 jobs in demand, total openings and their average salaries";
title2 "Table 1.3 " ;
proc sql outobs=10;
  select occupation, count(occupation) as total, mean(wage_rate_1) as average_salaries
  from mydata.final_dataset
  group by occupation
  order by total desc;
quit;

/*Top 10 employers holding majority number of visas*/
title "Top 10 employers holding majority number of visas";
title2 "Table 1.4 " ;
proc sql outobs=10;
  select employer, repeat('*',count(*)*.002) as Frequency
  from mydata.final_dataset
  group by employer
  order by Frequency desc ;
quit;

/* What job cateogry dominates visas? */
proc format ;
value job_code  
  1 -19 = "Engineering"
  20-29 = "Math & Sciences"
  30-39 = "Computer Related"
  40-49 = "Life Sciences"
  50-59 = "Social Sciences"
  70-79 = "Medicine & Health"
  90-99 = "Education"
  100-109 = "Library Sciences "
  110-119 = "Law"
  120-129 = "Religion"
  131-139 = "Writers "
  141-149 = "Art" 
  152-159 = "Entertainment"
  160-169 = "Administrative Specialization"
  180-189 = " Managers & Officials "
  195-199 = " Manegerial"
  other = "Unknown" ;
run;

/*Joining the format with the final_dataset*/
proc sql;
  create table mydata.segmentation as
  select employer,occupation, 
         state,city,job_code,put(job_code,job_code.) as jobcode, 
         wage_rate_1, nbr_immigrants
  from mydata.final_dataset;
quit;

/*Occupation breakdown of visas*/
goptions reset=all border;

proc gchart data=mydata.segmentation;
  title "Occupation breakdown for visas";
  title2 " Figure 2";
  pie jobcode/ value=none noheading
  percent=outside slice = outside;
run;


/*Breakdown of visa in 2007 by visa type*/
title "Breakdown of visas in 2007 by visa type";
title2 "Table 1.5 " ;
proc sql ;
  select program_designation1, count(*)as TotalNumber
  from fy7 
  where program_designation1 is not null
  group by program_designation1
  order by TotalNumber desc;
quit ;

/*Storing employers and their certified visas for 2002-2006*/
proc sql;
create table mydata.analysis__certified as (
  select employer, approval_status
  from mydata.final_dataset
  where approval_status = "Certified")
  order by employer asc;
quit;


/*Storing employers and their denied visas for 2002-2006*/
proc sql;
create table mydata.analysis_denied as 
  select employer, approval_status 
  from mydata.final_dataset
  where approval_status ='Denied';
quit;


/*Top 10 employers who are certified the visa by USCIS  */
title "Top 10 employers who are certified visas by USCIS";
title2 "Table 1.6 " ;
proc sql outobs=10;
  select employer, count(approval_status) as total_certified
  from mydata.final_dataset
  where approval_status ='Certified'
  group by  employer 
  order by total_certified desc;
quit;


/*Top 10 employers who are denied the visa by USCIS */
title "Top 10 employers who are denied visas by USCIS";
title2 "Table 1.7 " ;
proc sql outobs=10;
  select employer, count(approval_status) as total_denied
  from mydata.final_dataset
  where approval_status ='Denied'
  group by employer 
  order by total_denied desc;
quit;

ods rtf close;
