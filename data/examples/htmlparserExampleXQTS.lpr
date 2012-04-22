program htmlparserExampleXQTS;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, extendedhtmlparser, simplehtmltreeparser, pseudoxpath, bbutils , sysutils
  { you can add units after this };

const CATALOG_TEMPLATE = '<test-group><test-case is-XPath2="true" >{(path:=@FilePath,desc:=description,queryname:=query/@name,inputfile:=input-file,inputfilevar:=input-file/@variable,outputfile:=output-file,error:=expected-error, complete:="yes")}</test-case>*</test-group>';
var htp: THtmlTemplateParser;
    desc, queryname, inputfile, outputfile, error, path: string;
    i: Integer;
    query, output: String;
    skippedErrors, total, correct, wrong, exception: Integer;
    pxp: TPseudoXPathParser;
    tree: TTreeParser;
    myoutput: string;

type

{ twrapper }

 twrapper = class
  procedure eval(sender: TObject; const variable: string; var value: TPXPValue);
end;

var wrap: twrapper;
  CAT: Integer;
  inputfilevar: String;

{ twrapper }

procedure twrapper.eval(sender: TObject; const variable: string; var value: TPXPValue);
begin
  writeln(variable);
  if variable = 'input-context' then value := pxpvalue(tree.getTree);
end;

begin
  htp := THtmlTemplateParser.create;
  htp.parseTemplate(CATALOG_TEMPLATE);
  pxp := TPseudoXPathParser.create;
  pxp.OnEvaluateVariable:=@wrap.eval;
  tree := TTreeParser.Create;
  tree.readComments:=true;
  tree.readProcessingInstructions:=true;
  tree.trimText:=false;

  if paramstr(1) = '--simple' then begin
    writeln(pxp.evaluate(paramstr(2),nil).toString);
    exit;
  end;

  skippedErrors := 0; correct := 0; wrong := 0; total := 0; exception:=0;
  PXPGlobalTrimNodes:=false;
  for CAT:=1 to Paramcount() do begin;
    htp.parseHTMLFile(ParamStr(CAT));


    //writeln(htp.variableChangeLog.debugTextRepresentation);
    for i:=0 to htp.variableChangeLog.count-1 do begin
      if htp.variableChangeLog.getVariableName(i) = 'desc' then desc := htp.variableChangeLog.getVariableValueString(i)
      else if htp.variableChangeLog.getVariableName(i) = 'queryname' then queryname := htp.variableChangeLog.getVariableValueString(i)
      else if htp.variableChangeLog.getVariableName(i) = 'inputfile' then inputfile := htp.variableChangeLog.getVariableValueString(i)
      else if htp.variableChangeLog.getVariableName(i) = 'outputfile' then outputfile := htp.variableChangeLog.getVariableValueString(i)
      else if htp.variableChangeLog.getVariableName(i) = 'error' then error := htp.variableChangeLog.getVariableValueString(i)
      else if htp.variableChangeLog.getVariableName(i) = 'path' then path := htp.variableChangeLog.getVariableValueString(i)
      else if htp.variableChangeLog.getVariableName(i) = 'inputfilevar' then inputfilevar := htp.variableChangeLog.getVariableValueString(i)
      else if htp.variableChangeLog.getVariableName(i) = 'complete' then begin
        total += 1;
        if error <> '' then begin
          skippedErrors+=1;
          continue;
        end;
        query := strLoadFromFile('Queries/XQuery/'+path+'/'+queryname+'.xq');
        output := strLoadFromFile('ExpectedTestResults/'+path+'/'+outputfile);
        try
          query := StringReplace(query, 'declare variable $'+inputfilevar+' external;', '', [rfReplaceAll]);

          if inputfile = 'emptydoc' then myoutput := pxp.evaluate(query, nil).toString
          else begin
            pxp.RootElement:=tree.getTree;

            tree.parseTreeFromFile('TestSources/'+inputfile+'.xml');
            query := StringReplace(query, '$'+inputfilevar, '.', [rfReplaceAll]);
            myoutput := pxp.evaluate(query, tree.getTree).toString;
          end;
          if (myoutput = output) or (((myoutput = '0') or (myoutput = '-0')) and ((output = '0') or (output = '-0')))  then begin
            correct += 1;
            //writeln('PASS: ', copy(desc,1,30),queryname,' : got '  , myoutput);
          end else begin
            wrong+=1;
            write(stderr, 'WRONG: ', copy(desc,1,60),' ',queryname,' : got '  , myoutput, ' <> expected ', output, ' ');
            writeln(stderr, '       ', arrayGet(strSplit(query, #13),-2) );
            writeln('      TestSources/'+inputfile+'.xml', '  |  ','Queries/XQuery/'+path+'/'+queryname+'.xq','    |   ', 'ExpectedTestResults/'+path+'/'+outputfile); writeln;
          end;
        except on e: sysutils.Exception do begin
          writeln(stderr, 'EXCEPTION: ',desc, queryname, ': ', e.message);
          writeln('       ', arrayGet(strSplit(strTrim(query), #13),-1) );
          writeln('      TestSources/'+inputfile+'.xml', '  |  ','Queries/XQuery/'+path+'/'+queryname+'.xq','    |   ', 'ExpectedTestResults/'+path+'/'+outputfile); writeln;
          exception+=1;
        end;
          //writeln;}
        //writeln(desc, ': ', , 'Queries/XQuery/'+path+'/'+queryname+'.xq');
        //Exit;
      end;
     end;
    end;
  end;
  writeln(stderr, 'Correct:', correct, ' Wrong: ',wrong, ' Skipped: ',skippedErrors,' Crashed: ', exception,' / ', total);
end.
