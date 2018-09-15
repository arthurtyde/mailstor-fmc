#!/usr/bin/rexx
/*-----------------------------------------------------------+
|                                                            |
| download mail and archive (c)2018 by Arthur F. Tyde III    |
|                                                            |
+-----------------------------------------------------------*/

parse arg commands
call setup
call mainline
exit rc

setup:
/*-----------------------------------------------------------+
|                                                            |
+-----------------------------------------------------------*/
Parse Value Load_Configuration('/home/aftyde/mailstor/mailstor.cfg') with fatal_error
if commands\='' then do
  parse value Option_Processor(commands) with fatal_error
end
'/usr/bin/clear'
say '->' program
say ''
return

mainline:
/*-----------------------------------------------------------+
| Get total number of mails in each folder from a list       |
| Factor optimal chunks for fetchmail to grab                |
| Grab chunks of mail until there is no more                 |
|                                                            |
+-----------------------------------------------------------*/
Address SYSTEM
if dryrun=1 then say '-> Dry Run is set - no mail will actually be processed.'
do i=1 by 1 until i=folder.0
   say '-> Processing' folder.i' with config' config.i'.'
   '/bin/cp' config.i fmc
   parse value load_mailbox(folder.i) with target
   say '   Target:'target', factor:'strip(factor(target),'B')'.'
   if target>threshold & skip.i="no" then do
      say '   'target 'messages on server.'
      if target<=factor(target) then do 
         jump=10
      end
      else do
         parse value reverse(factor(target)) with jump .
         if jump>100 then do
            jump=10
         end
      end
      jump=5
      do count=0 by jump until count>=target
         say '-> 'count' messages processed in chunks of' jump'...'
         if dryrun=0 then do /* fm is a pos, it will crash, bitch and moan - just re-run */
            '/usr/bin/fetchmail -a -B' jump '--folder' '"'folder.i'" 1>/dev/null 2>/dev/null || exit 0' 
            '/bin/sleep' psec
         end
         else do
            say '   /usr/bin/fetchmail -s -a -B' jump '--folder' '"'folder.i'"' 
            say '   /bin/sleep' psec
         end
      end
   end
   else do
      if skip.i="yes" then do
         say '   Skipped per configuration file directive -' target 'messages on server.'
      end
      else do
         say '   Not enough mail ('target'/'threshold') to download in' folder.i'...'
      end
   end
end
return

Load_Mailbox: /* figure out how many mail items are in the mailbox */
parse arg config
Address SYSTEM
if stream(mwf,'C','QUERY EXISTS')='' then do
  /**/
end
else do
  '/bin/rm' mwf redirect dn
end
command='/usr/bin/fetchmail -N --folder "'config'"' redirect''mwf se
command '|| exit 0'
parse value linein(mwf) with temp .
parse value stream(mwf,'C','CLOSE') with xrc
if temp='fetchmail:' then temp=0
xrc=temp
return xrc

factor:  
numeric digits 1000                              /*handle thousand digits for the powers*/
parse arg  bot  top  step   base  add            /*get optional arguments from the C.L. */
if  bot==''   then do;  bot=1;  top=100;  end    /*no  BOT given?  Then use the default.*/
if  top==''   then              top=bot          /* "  TOP?  "       "   "   "     "    */
if step==''   then step=  1                      /* " STEP?  "       "   "   "     "    */
if add ==''   then  add= -1                      /* "  ADD?  "       "   "   "     "    */
tell= top>0;       top=abs(top)                  /*if TOP is negative, suppress displays*/
w=length(top)                                    /*get maximum width for aligned display*/
if base\==''  then w=length(base**top)           /*will be testing powers of two later? */
@.=left('', 7);   @.0="{unity}";   @.1='[prime]' /*some literals:  pad;  prime (or not).*/
numeric digits max(9, w+1)                       /*maybe increase the digits precision. */
#=0                                              /*#:    is the number of primes found. */
        do n=bot  to top  by step                /*process a single number  or  a range.*/
        ?=n;  if base\==''  then ?=base**n + add /*should we perform a "Mercenne" test? */
        pf=factr(?);      f=words(pf)            /*get prime factors; number of factors.*/
        if f==1  then #=#+1                      /*Is N prime?  Then bump prime counter.*/
        end   /*n*/
ps= 'primes'
if p==1  then ps= "prime"       /*setup for proper English in sentence.*/
return pf


/*──────────────────────────────────────────────────────────────────────────────────────*/
factr: procedure;  parse arg x 1 d,$             /*set X, D  to argument 1;  $  to null.*/
if x==1  then return ''                          /*handle the special case of   X = 1.  */
       do  while x//2==0;  $=$ 2;  x=x%2;  end   /*append all the  2  factors of new  X.*/
       do  while x//3==0;  $=$ 3;  x=x%3;  end   /*   "    "   "   3     "     "  "   " */
       do  while x//5==0;  $=$ 5;  x=x%5;  end   /*   "    "   "   5     "     "  "   " */
       do  while x//7==0;  $=$ 7;  x=x%7;  end   /*   "    "   "   7     "     "  "   " */
                                                 /*                                  ___*/
q=1;   do  while q<=x;  q=q*4;  end              /*these two lines compute integer  √ X */
r=0;   do  while q>1;   q=q%4;  _=d-r-q;  r=r%2;   if _>=0  then do; d=_; r=r+q; end;  end
 
       do j=11  by 6  to r                       /*insure that  J  isn't divisible by 3.*/
       parse var j  ''  -1  _                    /*obtain the last decimal digit of  J. */
       if _\==5  then  do  while x//j==0;  $=$ j;  x=x%j;  end     /*maybe reduce by J. */
       if _ ==3  then iterate                    /*Is next  Y  is divisible by 5?  Skip.*/
       y=j+2;          do  while x//y==0;  $=$ y;  x=x%y;  end     /*maybe reduce by J. */
       end   /*j*/
                                                 /* [↓]  The $ list has a leading blank.*/
if x==1  then return $                           /*Is residual=unity? Then don't append.*/
return $ x                         /*return   $   with appended residual. */




Load_Configuration:
/*-----------------------------------------------------------+
| Load and process the configuration file.                   |
+-----------------------------------------------------------*/
parse arg config
parse value charin(config,1,stream(config,'C','QUERY SIZE')-2) with opts
call stream config,'C','CLOSE'
Parse Value Option_Processor(opts) with Fatal_Error
return fatal_error

Option_Processor:
/*-----------------------------------------------------------+
| Interpret the statements in the configuration file.        |
| Expanded to allow the redefinition of environment variables|
| where enclosed in CHR$(233)'s.  Also added ability to call |
| functions and insert the resolution values.                |
|                                                            |
+-----------------------------------------------------------*/
parse arg opts
if opts<>'' then do
   opts = Strip(opts,"L","(")
   Do While opts \= ""
     Parse Value Parse_Next_Opt() With Cur_opt Parms
     opt=translate(cur_opt,'',d2c(10)d2c(13))
     if pos('�',parms)>0 then do /* process function */
        /*-----------------------------------------------------------+
        | Process embedded function calls                            |
        +-----------------------------------------------------------*/
        parse value parms with p1'�'mid'�'p2
        select
           when pos('�',mid)>0 then do /* environment var into function */
              parse value mid with pp1'�'newmid'�'pp2
              expres=pp1'("'Value(newmid,,'OS2ENVIRONMENT')'")'pp2
              interpret 'parse value' expres 'with mid'
           end
           when pos('�',mid)>0 then do /* environment var into function */
              /*-----------------------------------------------------------+
              | Support environment vars in function calls.                |
              +-----------------------------------------------------------*/
              parse value mid with pp1'�'newmid'�'pp2
              expres=pp1'("'newmid'")'pp2
              interpret 'parse value' expres 'with mid'
           end
           otherwise do
              /**/
           end
        end
        parms=p1||mid||p2
     end
     if pos('�',parms)>0 then do
        /*-----------------------------------------------------------+
        | Resolve embedded environment variables.                    |
        +-----------------------------------------------------------*/
        parse value parms with p1'�'mid'�'p2
        parms=p1||Value(mid,,'OS2ENVIRONMENT')||p2
     end
     interpret opt'="'parms'"'
   End
end
else do
   fatal_error=-1
end
return fatal_error

Parse_Next_Opt:
/*-----------------------------------------------------------+
|                                                            |
+-----------------------------------------------------------*/
  Procedure Expose Opts
  Parse Value opts With y opts
  If Pos("(",y)>0 Then Do
    Parse Value y With y"("rest
    opts = "("rest opts
  End
  opts = Strip(opts,"B")
  y = Strip(y,"B")
  If Left(opts,1)="(" Then Do
    indent = 0
    Do j=1 To Length(opts) Until indent=0
      If Substr(opts,j,1)="(" Then indent = indent + 1
      If Substr(opts,j,1)=")" Then indent = indent - 1
    End
    parms = Strip(Substr(opts,2,j-2),"B")
    opts = Substr(opts,j+1)
  End
  Else parms = ""
Return Y Parms

Exists:
/*-----------------------------------------------------------+
| Exists - Check for the Existance of a File or Subdirectory |
|                                                            |
| Change History                                             |
|                                                            |
| Vers   Date   Description of Change                        |
| 1.00 ??/??/?? Initial Code Creation                        |
| 1.01  1/19/95 Added code to begin supporting DRIVE option  |
| 1.02  7/22/10 Removed UPPER in parse to support mixed case |
+-----------------------------------------------------------*/
Parse Arg Exists_Source,Exists_Type,Exists_Options
Exists_Type = Left(Exists_Type,1)
If Exists_Type = '' Then Exists_Type = 'F' /* Default to file checks */
Exists_rc = 0
Exists_return_String = ''
Select
  /*-----------------------------------------------------------+
  | Check for File existance                                   |
  +-----------------------------------------------------------*/
  When Exists_Type = 'F' Then Do
   Exists_rc = Stream(Exists_Source,'Command','Query Exists') \= ''
  End
  /*-----------------------------------------------------------+
  | Check for Sub-Directory existance                          |
  +-----------------------------------------------------------*/
  When Exists_Type = 'F' Then Do
   Exists_rc = Stream(Exists_Source,'Command','Query Exists') \= ''
  End
  /*-----------------------------------------------------------+
  | Check for Sub-Directory existance                          |
  +-----------------------------------------------------------*/
  When Exists_Type = 'S' Then Do
    If Right(Exists_Source,1)=':' Then Exists_Source = Exists_Source'\'
    Exists_Save_Dir = Directory()
    Call Directory Exists_Source
    Exists_new_Dir = Directory()
    Exists_rc = (Translate(Exists_New_Dir) = Exists_Source)
    Call Directory Exists_Save_Dir
  End
  /*-----------------------------------------------------------+
  | Check for Drive existance                                  |
  +-----------------------------------------------------------*/
  When Exists_Type = 'D' Then Do
    Exists_Rc = (Pos(Translate(Left(Exists_Source,1)),SysDriveMap()) > 0)
  End
  Otherwise
    Say 'Exist does not support a sub function of' Exist_type
End
Return Exists_rc||Exists_return_string
