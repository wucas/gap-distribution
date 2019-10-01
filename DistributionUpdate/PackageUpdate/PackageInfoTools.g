###########################################################################
##  
##  PackageInfoTools.g                                         (C) Frank Lübeck
##  
##  
##  This file contains utilities for automatic updating of the information 
##  related to package which are available via the GAP website. 
##  
##     - current PackageInfo.g files are fetched from the Web
##     - if something is new, the following files are updated:
##       - changed archives are downloaded, if any of the formats
##         .zip, .tar.gz, -win.zip or .tar.bz2 is not provided these
##         are automatically generated
##       - if  package archives have changed, the  merged archives 
##         (in the formats mentioned above) are newly generated
##       - if a documentation archive for the online manual has changed, it is
##         fetched from the Web and unpacked

## setting global variable to store package infos
PACKAGE_INFOS := rec();

## should be told the 'mixer' directly
GAPLibraryVersion := "unknown";
GAPKernelVersion := "unknown";

## clear the global variable PACKAGE_INFOS
ClearPACKAGE_INFOS := function()
  local a;
  for a in NamesOfComponents(PACKAGE_INFOS) do
    Unbind(PACKAGE_INFOS.(a));
  od;
end;

# try reading a PackageInfo.g file, given by name fname
READPackageInfo := function(fname)
  local r, name;
  Unbind(GAPInfo.PackageInfoCurrent);
  READ(fname);
  if not IsBound(GAPInfo.PackageInfoCurrent) then
    Print("# Error (", fname, "): no package info bound!\n");
    return;
  fi;
  r := GAPInfo.PackageInfoCurrent;
  Unbind(GAPInfo.PackageInfoCurrent);
  # store under normalized .PackageName
  if not IsRecord(r) or not IsBound(r.PackageName) or 
                        not IsString(r.PackageName) then
    Print("# Warning (", fname, "): ignored, no package name!\n");
    return;
  fi;
  NormalizeWhitespace(r.PackageName);
  name := LowercaseString(r.PackageName);

  # What is the "default Status"???
  if not IsBound(r.Status) then
     r.Status := "None";
     Print("# Warning (", r.PackageName, "): package has no Status!!!\n");
  fi;

  PACKAGE_INFOS.(name) := r;
end;


#####   some utilities       ###################################################

# get file/directory list 
# args: [dir[, type[, depth]]]  (default dir is ".", type as in 'find xxx -type type')
FilesDir := function(arg)
  local dir, type, depth, aa, path, find, outstr, out, p;
  if Length(arg) > 0 then
    dir := arg[1];
  else
    dir := ".";
  fi;
  if Length(arg) > 1 then
    type := arg[2];
  else
    type := -1;
  fi;
  if Length(arg) > 2 then
    depth := arg[3];
  else
    depth := 1000;
  fi;
  aa := [dir];
  if type <> -1 then
    Append(aa, ["-type", type]);
  fi;
  Append(aa, ["-maxdepth", String(depth), "-print0"]);
  path := DirectoriesSystemPrograms();
  find := Filename( path, "find" );
  outstr := "";
  out := OutputTextString(outstr,false);
  p := Process(DirectoryCurrent(), find, InputTextNone(), out, aa);
  CloseStream(out);
  return SplitString(outstr,"","\000");
end;

# part of string str before last '/', or "." if there is no '/' 
Dirname := function(str)
  local len;
  len := Length(str);
  while len > 0 and str[len] <> '/' do
    len := len - 1;
  od;
  if len = 0 then
    return ".";
  else
    return str{[1..len-1]};
  fi;
end;
    
# part of string str after last '/', or str if there is no '/' 
Basename := function(str)
  local len;
  len := Length(str);
  while len > 0 and str[len] <> '/' do
    len := len - 1;
  od;
  if len = 0 then
    return str;
  else
    return str{[len+1..Length(str)]};
  fi;
end;
#T Better introduce general ``text processing'' functions
#T  LeftString( <str>, <pattern> )
#T  RightString( <str>, <pattern> )
#T  LeftBackString( <str>, <pattern> )
#T  RightBackString( <str>, <pattern> )
#T which return the substring in <str> before/after the first/last occurrence
#T of the string <pattern>.

# arg:   cmd, arg1, arg2, ...
StringSystem := function(arg)
  local cmd, res, inp, out;
  cmd := arg[1];
  if cmd[1] <> '/' then
    cmd := Filename(DirectoriesSystemPrograms(), cmd);
  fi;
  if not IsString(cmd) then
    return fail;
  fi;
  res := "";
  inp := InputTextUser();
  out := OutputTextString(res, false);
  Process(DirectoryCurrent(), cmd, inp, out, arg{[2..Length(arg)]});
  CloseStream(out);
  return res;
end;

StringCurrentTime := function()
  local str, date, out;
  str := "";
  date := Filename(DirectoriesSystemPrograms(), "date");
  out := OutputTextString(str, false);
  Process(DirectoryCurrent(), date, InputTextUser(), out,
  ["-u", "+%Y_%m_%d-%H_%M_UTC"]);
  CloseStream(out);
  return Chomp(str);
end;

# string for size of file with name fn, like "13kB" or "2.9MB"
StringSizeFilename := function(fn)
  local res;
  if not IsExistingFile(fn) then
    Print("#I StringSizeFilename, didn't find: ", fn, "\n");
    return "n.a.";
  fi;
  res := StringSystem("sh", "-c", Concatenation("du -h ", fn, "|cut -f 1"));
  while res[Length(res)] = '\n' do
    Unbind(res[Length(res)]);
  od;
  if res[Length(res)] in "kM" then
    Add(res, 'B');
  fi;
  return res;
end;

# checks if an archive file doesn't contain path with ".." in them or
# starting with "/".
# assuming that fname ends in one of:  ".zip", ".tar.gz" or ".tar.bz2"
IsLocalArchive := function(fname)
  local ext, s;
  ext := fname{[Length(fname)-3..Length(fname)]};
  if ext = "r.gz" then
    s := StringSystem("tar", "tzf", fname);
  elif ext = ".bz2" then
    s := StringSystem("tar", "tf", fname, "--bzip2");
  elif ext = ".zip" then
    s := StringSystem("unzip", "-qql", fname);
  else
    s := "..";
  fi;
  return PositionSublist(s, "..") = fail and PositionSublist(s, " /") = fail;
end;


ReadAllPackageInfos := function(pkgdir)
  local pkgs, pkg;
  pkgs := Difference(FilesDir(pkgdir, "d", 1), [pkgdir]);
  for pkg in pkgs do
    READPackageInfo(Concatenation(pkg, "/PackageInfo.g"));
  od;
end;


# returns list of names of dirs with updated package info
UpdatePackageInfoFiles := function(pkgdir)
  local path, find, wget, date, stdin, stdout, res, outstr, out, p, 
        pkgs, nam, info, infon, namn, d, pkg, f, update, has_error,
        passes, t;
  path := DirectoriesSystemPrograms();
  find := Filename( path, "find" );
  wget := Filename( path, "wget" );
  stdin := InputTextUser();
  stdout := OutputTextUser();
  res := [];
  # get directory list 
  pkgs := Difference(FilesDir(pkgdir, "d", 1), [pkgdir]);

  for pkg in pkgs do
    # we allow up to two passes over the body of the loop, so when the new
    # PackageInfoURL will be given, we will read new PackageInfo.g from the 
    # new location and repeat all steps once again
    passes:=0;
    has_error := false;

    repeat
    
      # Read locally stored information about the package. After the call
      # to the 'addPackages' function to initialize handling of a package
      # this consists at least of the following:
      #  - the corresponding directory (all small letters);
      #  - the 'slim' pkgname/PackageInfo.g file having only its 
      #    .PackageName, .PackageInfoURL and .Status components set.
      ClearPACKAGE_INFOS();
      READPackageInfo(Concatenation(pkg, "/PackageInfo.g"));
      nam := NamesOfComponents(PACKAGE_INFOS);
      if Length(nam) = 0 then
        Print( pkg, ": IGNORED (bad local version of PackageInfo.g)\n" );
        has_error:=true;
        continue;
      else
        nam := nam[1];
        info := PACKAGE_INFOS.(nam);
      fi;
      Print("Package: ", info.PackageName, "\n");

      if not IsBound( info.PackageInfoURL ) then
        Print("#  ERROR (", info.PackageName, "): PackageInfoURL not bound \n",
              "#  in the local version of PackageInfo.g. To set it, edit the file\n",
              "#  'currentPackageInfoURLList' and then call\n",
              "#  ./addPackages currentPackageInfoURLList\n");
        has_error:=true;
        continue;
      fi; 
            
      # try to get current info file with wget
      Exec(Concatenation("mkdir -p ", pkg, "/tmp; rm -f ", pkg, "/tmp/tmpinfo.g"));
      Exec(Concatenation("wget --timeout=60 --tries=1 -O ", pkg, "/tmp/tmpinfo.g ",
      info.PackageInfoURL, " 2>> wgetlog"));
      ClearPACKAGE_INFOS();
      # error if download unseccessful or if the file is not GAP readable
      # TODO: possibly improve the check that the content is appropriate
      READPackageInfo(Concatenation(pkg, "/tmp/tmpinfo.g"));
      if not IsBound(PACKAGE_INFOS.(nam)) then
        Print("  WARNING (", info.PackageName, "): no success in download of the current info file \n  from ", 
              info.PackageInfoURL, "\n");
        has_error:=true;
        continue;
      fi;
    
      infon := PACKAGE_INFOS.(nam);
    
      # helper, because "=" for functions doesn't work as it should
      f := function(a)
        if not IsBound(infon.(a)) then
          return false;
        elif IsFunction(info.(a)) then
          return StringPrint(info.(a)) = StringPrint(infon.(a));
        else
          return info.(a) = infon.(a);
        fi;
      end;
    
      nam := NamesOfComponents(info);
      namn := NamesOfComponents(infon);

      # any different components?
      if nam = namn and ForAll(nam, f) then
        Print("  No changes in PackageInfo.g file.\n");
        update := false;
        continue;
      fi;

      # any removed components?
      d := Difference(nam, namn);
      if Length(d) > 0 then
        Print("  removed components: ", d, "\n");
        update := true;
        if "PackageInfoURL" in d then
          Print("  ERROR (", info.PackageName, "): no .PackageInfoURL component in the new info file from\n   ",
                info.PackageInfoURL, "\n  info file will not be changed\n");
          has_error := true;
        fi;  
        if "Version" in d then
          Print("  ERROR (", info.PackageName, "): no .Version component in the new info file from\n   ",
                info.PackageInfoURL, "\n  info file will not be changed\n");
          has_error := true;
        fi;  
      fi;

      # any new components?
      d := Difference(namn, nam);
      if Length(d) > 0 then
        Print("  new components: ", d, "\n");
        update := true;
      fi;

      # any changed components?
      d := Filtered(nam, t -> not f(t));
      if Length(d) > 0 then
        Print("  changed components: ", d, "\n");
        update := true;
        if IsBound(info.Version) and not "Version" in d then
          Print("  ERROR (", info.PackageName, "): There are changed components in the new info file from\n  ",
                info.PackageInfoURL, "\n   but .Version remains the same. ",
                "This is not allowed, so the info file will not be changed\n");
          has_error := true;
        fi;    
        if IsBound(info.Version) and not CompareVersionNumbers( infon.Version, info.Version ) then
          Print("  ERROR (", info.PackageName, "): the new version ", infon.Version, 
                " in the new info file from\n  ", info.PackageInfoURL, 
                "\n  is not larger than the old version ", info.Version, 
                "\n  This is not allowed, so the info file will not be changed\n");
          has_error := true;
        fi;

        # function to check wheter a date given as a list of three integers
        # [day, month, year] is a plausible date
        IsPlausibleDate := date -> date[1] in [1..31] and
	                   date[2] in [1..12] and
	                   date[1] in [ 1..DaysInMonth( date[2], date[3] ) ];

        if IsBound( infon.Date ) then
          # look for date in format mm/dd/yyyy
          if IsString( infon.Date ) and Length( infon.Date ) = 10 
            and infon.Date{ [3,6] } = "//" 
            and ForAll( infon.Date{ [1,2,4,5,7,8,9,10] }, IsDigitChar ) then
            date := List( SplitString( infon.Date, "/" ), Int ); 
            # here date=[dd,mm,yyyy]
            # the format dd/mm/yyyy is ambigous and can be confused with mm/dd/yyyy 
            # if it is clear from the date that the format is mm/dd/yyyy 
            # print a message hinting at that mistake and to tell the user 
            # what the correct format is.
            if date[2] in [13..31] and date[1] in [1..12] then
              Print("  ERROR (", info.PackageName, "): it seems that in the",
                " given package release date ", infon.Date,
                " day and month are switched.",
                " The date should be of the form `yyyy-mm-dd`",
                " or `dd/mm/yyyy`\n" );
              has_error := true;
              # unbind date so that we can check later whether an error 
              # was found by checking if date is bound
              Unbind( date );
            fi;
          # look for date in ISO-8601 format yyyy-mm-dd
          elif IsString( infon.Date ) and Length( infon.Date ) = 10 
            and infon.Date{ [5,8] } = "--" 
            and ForAll( infon.Date{ [1,2,3,4,6,7,9,10] }, IsDigitChar ) then
            date := List( SplitString( infon.Date, "-" ), Int);
            date := date{ [3,2,1] }; # sort such that date=[dd,mm,yyyy]
          else
            Print("  ERROR (", info.PackageName, "): the given package release",
              " date should be a string of the form `yyyy-mm-dd`",
              " or `dd/mm/yyyy' representing a date since 1999 but the",
              " given date ", infon.Date, " is not\n" );
            has_error := true;
            # unbind date so that we can check later whether an error 
            # was found by checking if date is bound
            Unbind( date ); 
          fi;
          if IsBound( date ) and not IsPlausibleDate( date ) then
            Print("  ERROR (", info.PackageName, "): the given package release",
              " date ", infon.Date,
              " seems not to be a valid date\n" );
            has_error := true;
          fi;
          # GAP 4 appeared in 1999 thus any package release date before 1999
          # cannot be valid
          if IsBound( date ) and date[3] < 1999 then
            Print("  ERROR (", info.PackageName, "): the package",
              " release date must be in 1999 or later but the given date ", 
              infon.Date,
              " is not\n");
            has_error := true;
          fi;
        else
          Print("  ERROR (", info.PackageName, "): no date is bound\n" );
        fi;
      fi;
    
      if update then
        if not has_error then
          # save old info file, store new one
          outstr := StringCurrentTime();
          Exec(Concatenation("mv -f ", pkg, "/PackageInfo.g ", pkg, 
                             "/PackageInfo.g-", outstr));
          Exec(Concatenation("mv -f ", pkg, "/tmp/tmpinfo.g ", pkg,
                             "/PackageInfo.g"));
          Add(res, [ infon.PackageName, infon.Version ] );
        else 
          Print("  PackageInfo.g is not accepted because of an error.\n");
        fi;
      fi;
    
      # will we need another pass?
      if "PackageInfoURL" in d then 
        if passes = 1 then
          Print("  New URL of PackageInfo.g file is given - repeating update one more time\n");
        fi;  
      else
        # PackageInfoURL unchanged - no more passes
        update:=false;
      fi;
    
    passes:=passes+1;
    until passes >= 2 or not update or has_error;
  od;
  return res;
end;

# For a new setup of the system one can use the output of this
# function for the initializations of all currently handled packages.
AddpackageLinesCurrent := function(pkgdir)
  local path, find, pkgs, resstr, res, nam, info, pkg;
  path := DirectoriesSystemPrograms();
  find := Filename( path, "find" );
  # get directory list 
  pkgs := Difference(FilesDir(pkgdir, "d", 1), [pkgdir]);
  resstr := "";
  res := OutputTextString(resstr, false);
  SetPrintFormattingStatus(res, false);

  for pkg in pkgs do
    # read local info
    # to initialize handling of a package just 
    #  - create corresponding directory (all small letters)
    #  - provide a 'slim' pkgname/PackageInfo.g file,
    #    setting only the .PackageName and .PackageInfoURL components
    ClearPACKAGE_INFOS();
    READPackageInfo(Concatenation(pkg, "/PackageInfo.g"));
    nam := NamesOfComponents(PACKAGE_INFOS);
    if Length(nam) = 0 then
      Print("# ", pkg, ": IGNORED\n");
      continue;
    else
      nam := nam[1];
      info := PACKAGE_INFOS.(nam);
    fi;
    PrintTo(res, "./addPackage ", info.PackageName, " ", 
            info.PackageInfoURL,"\n");
  od;
  CloseStream(res);
  return resstr;
end;

# returns list of dirs with updated archives
UpdatePackageArchives := function(pkgdir, pkgreposdir, webdir)
  local pkgs, res, nam, info, infostored, infoarchive, url, pos, fname, 
        formats, pkgtmp, missing, available, fmt, lines, l, ll, fun, pkg, 
        p, a, bname, dnam, old, fn, populated, pkgdirname;
  # package dirs
  pkgs := Difference(FilesDir(pkgdir, "d", 1), [pkgdir]);
  # make sure the needed subdirs of the webdir exist
  Exec(Concatenation("mkdir -p ", webdir, "/Packages/pkg"));
  Exec(Concatenation("mkdir -p ", webdir, "/ftpdir/tar.gz/packages"));
  Exec(Concatenation("mkdir -p ", webdir, "/ftpdir/tar.bz2/packages"));
  Exec(Concatenation("mkdir -p ", webdir, "/ftpdir/zip/packages"));
  Exec(Concatenation("mkdir -p ", webdir, "/ftpdir/win.zip/packages"));

  res := [];
  for pkg in pkgs do
    pkgtmp := Concatenation(pkg, "/tmp/");
    ClearPACKAGE_INFOS();
    READPackageInfo(Concatenation(pkg, "/PackageInfo.g"));
    nam := NamesOfComponents(PACKAGE_INFOS);
    if Length(nam) = 0 then
      Print( pkg, ": IGNORED (bad local version of PackageInfo.g)\n" );
      continue;
    fi;
    nam := nam[1];
    info := PACKAGE_INFOS.(nam);
    # if there never been a successful import of the package, the PackageInfo.g
    # will still be rudimentary, with the only components being `PackageName`,
    # `PackageInfoURL` and `Status:="unknown"`.
    if not IsBound(info.Version) then
      Print( pkg, ": IGNORED (incomplete local version of PackageInfo.g)\n" );
      continue;
    fi;
    pkgdirname := LowercaseString( NormalizedWhitespace( info.PackageName ) );
    # we update to the tip before doing any other actions to ensure that 
    # in case of any errors the latest version of the package will be used
    Exec( Concatenation( "cd ", pkgreposdir,  "/", pkgdirname, " ; hg update -r tip" ) );
    # if the package release repository is already populated, which 
    # latest version of the package is stored there?
    if IsExistingFile( Concatenation( pkgreposdir, "/", pkgdirname, "/PackageInfo.g") ) then
      ClearPACKAGE_INFOS();
      READPackageInfo( Concatenation( pkgreposdir, "/", pkgdirname, "/PackageInfo.g") );
      nam := NamesOfComponents(PACKAGE_INFOS);
      if Length(nam) = 0 then
        Print( pkg, ": IGNORED (can't read PackageInfo.g from the repository)\n" );
        continue;
      fi;
      nam := nam[1];
      infostored := PACKAGE_INFOS.(nam);
      populated:=true;
    else
      populated:=false;
    fi;  

    Print("* ", info.PackageName, " ");
   
    # do we have the newer version of the package 
    # in the most recent PackageInfo.g file?
    if populated and info.Version = infostored.Version then
      Print(info.Version, " is already in collection\n");
    else
      # ok, so we have to get the archives
      Print("- new version ", info.Version, " discovered!!!\n");
      Print("  ============================================\n");
      if not IsBound(info.ArchiveURL) then
        Print("# ERROR (", info.PackageName, "): no ArchiveURL given!\n");
        continue;
      fi;
      url := info.ArchiveURL;
      # filename of the archive without extension
      fname := Basename(url);
      Add(res, nam);
      formats := SplitString(info.ArchiveFormats,""," \n\r\t,");
      # use only acceptable formats here
      formats := Intersection( 
                   formats, [ ".tar.gz", ".tar.bz2", ".zip", "-win.zip" ]);
      Print("  Getting new archives from \n  ", url, formats, "\n");
      Exec(Concatenation("rm -rf ", pkgtmp));
      Exec(Concatenation("mkdir -p ", pkgtmp));
      # copy available archive formats
      for fmt in formats do
        Exec(Concatenation("cd ", pkgtmp, ";wget --timeout=60 --tries=1 -O ", 
             fname, fmt, " ", url, fmt, " 2>> wgetlog"));
      od;

      # which acceptable formats are available?
      available := Filtered([ ".tar.gz", ".tar.bz2", ".zip", "-win.zip" ],
                     fmt -> IsExistingFile(Concatenation(pkgtmp, fname, fmt)));

      # which acceptable formats were promised as available but in fact are not?
      missing := Filtered( formats, 
                   fmt -> not IsExistingFile(Concatenation(pkgtmp, fname, fmt)));  
      if Length( missing ) > 0 then
        Print("WARNING: ", info.PackageName, 
              " has the following formats promised in the PackageInfo.g file\n  but missing: ", 
              missing, "\n");
      fi;
       
      if Length(available)=0 then 
        Print("ERROR: for ", info.PackageName, " no archives are available!!!\n");
        Unbind(res[Length(res)]);
        continue;
      fi;
      
      fmt:=available[1];
      
      if not IsLocalArchive(Concatenation(pkgtmp, fname, fmt)) then
        Print("   archive rejected: it has a path starting with '/' or containing '..'\n");
        continue;
      fi;
      
      # we need to unpack at least one archive to classify text/binary files
      Print("  unpacking ", fname, fmt, "\n");
      if fmt = ".tar.gz" then
        Exec(Concatenation("cd ", pkgtmp, ";gzip -dc ", fname, 
                           ".tar.gz |tar xpf - "));
      elif fmt = ".tar.bz2" then
        Exec(Concatenation("cd ", pkgtmp, ";bzip2 -dc ", fname, 
                           ".tar.bz2 |tar xpf - "));
      elif fmt = "-win.zip" then
        Exec(Concatenation("cd ", pkgtmp, ";unzip -a ", fname, "-win.zip"));
      elif fmt = ".zip" then
        Exec(Concatenation("cd ", pkgtmp, ";unzip -a ", fname, ".zip"));
      else
        Print("ERROR (", info.PackageName, "): no recognized archive format ", fmt, "\n");
        continue;
      fi;
      
      # name of unpacked directory (must no longer be 'nam')
      dnam := Difference(FilesDir(pkgtmp, "d", 1), [pkgtmp]);
      if Length(dnam) = 0 then
        Print("ERROR (", info.PackageName, "): could not unpack archive .... SKIPPING !!!\n");
        continue;
      else
        dnam := dnam[1];
      fi;
      dnam := dnam{[Length(pkgtmp)+1..Length(dnam)]};
      # remove initial "/"
      if dnam[1]='/' then
        dnam := dnam{[2..Length(dnam)]};
      fi;
      
      # Do not import package if the version in the archive differs from 
      # the one claimed in the PackageInfo.g file on the package website.
      # TODO: Warning if something else in the PackageInfo.g file on web
      # website differs from PackageInfo.g file in the archive. 
      if IsExistingFile( Concatenation(pkgtmp, "/", dnam, "/PackageInfo.g") ) then
          ClearPACKAGE_INFOS();
          READPackageInfo( Concatenation(pkgtmp, "/", dnam, "/PackageInfo.g") );
          nam := NamesOfComponents(PACKAGE_INFOS);
          if Length(nam) = 0 then
             Print( pkg, ": IGNORED (can't read PackageInfo.g from the archive)\n" );
             continue;
          fi;
          nam := nam[1];
          infoarchive := PACKAGE_INFOS.(nam);
          if info.Version <> infoarchive.Version then
              Print("  ERROR (", info.PackageName, "): ",
              "PackageInfo.g on web refers to version ", info.Version, ", but \n",
              "PackageInfo.g in the archive has version ", infoarchive.Version, "! SKIPPING!!!\n");
              continue;
          fi;
          else
           Print("  ERROR (", info.PackageName, "): there is no PackageInfo.g file in the archive! SKIPPING!!!\n");
           continue;
      fi; 
      
      if not ValidatePackageInfo( Concatenation(pkgtmp, "/", dnam, "/PackageInfo.g")) then
           Print("  ERROR (", info.PackageName, "): validation of the info file not successful! SKIPPING!!!\n");
           continue;
      else
           Print("  Validation of the info file successful!\n");
      fi;

      if not info.Status in ["accepted","submitted","deposited"] then
        Print("WARNING (", info.PackageName, "): has status ", info.Status, 
              "\nwhich is is not one of accepted/submitted/deposited\n");
      fi;
      
      if IsBound( info.Dependencies ) then
        Print("  Package ", info.PackageName, 
              " ", info.Version,
              " from ", info.Date, " has dependencies:\n");
        for a in RecNames( info.Dependencies ) do
          if Length( info.Dependencies.(a) ) > 0 then
            Print("  * ", a, " ", info.Dependencies.(a), "\n");
          fi;
        od;
      fi;
    
      # need to find out the text files
      Print("  finding text files  . . .\n");
              PrintTo( Concatenation(pkgtmp, "patternstextbinary.txt" ), "#Autogenerated by GAP\n" );
      Exec( Concatenation ( "cd ", pkgtmp, " ; touch patternstextbinary.txt" ) );

      if Number( [IsBound(info.TextFiles), IsBound(info.BinaryFiles), IsBound(info.TextBinaryFilesPatterns) ],
                 a -> a=true ) > 1 then
        Print("  WARNING (", info.PackageName, 
              "): do not use more than one of TextFiles, BinaryFiles, TextBinaryFilesPatterns\n");
        Print("          The superfluous components will be ignored.\n");
      fi;           

      if IsBound(info.TextFiles) then
        Print("  using ", info.TextFiles, " from PackageInfo.g as text files \n");
        AppendTo( Concatenation(pkgtmp, "patternstextbinary.txt" ), "# Autoextended by GAP\n" );
        for a in info.TextFiles do
          AppendTo( Concatenation(pkgtmp, "patternstextbinary.txt" ), "T", a, "\n" );
        od;
      elif IsBound(info.BinaryFiles) then
        Print("  using ", info.BinaryFiles, " from PackageInfo.g as binary files \n");
        AppendTo( Concatenation(pkgtmp, "patternstextbinary.txt" ), "# Autoextended by GAP\n" );
        for a in info.BinaryFiles do
          AppendTo( Concatenation(pkgtmp, "patternstextbinary.txt" ), "B", a, "\n" );
        od;
      elif IsBound(info.TextBinaryFilesPatterns) then
        Print("  using ", info.TextBinaryFilesPatterns, " from PackageInfo.g to set text/binary patterns \n");
        AppendTo( Concatenation(pkgtmp, "patternstextbinary.txt" ), "# Autoextended by GAP\n" );
        for a in info.TextBinaryFilesPatterns do
          AppendTo( Concatenation(pkgtmp, "patternstextbinary.txt" ), a, "\n" );
        od;  
      fi;
      
      # classify text/binary files with Max's script classifyfiles.py
      Exec( Concatenation (
        "cp ../classifyfiles.py ", pkgtmp, "/ ; ",
        "cp ../patternscolorpkg.txt ", pkgtmp, "/patternscolor.txt ;",
        "cat ../patternstextbinary.txt >> ", pkgtmp, "/patternstextbinary.txt ;",
        "echo \"B*\" >> ", pkgtmp, "/patternstextbinary.txt ; ",
        "cd ", pkgtmp, " ; ",
        "python ./classifyfiles.py ", dnam ) );           
 
      Print("\n=====================text files==========================\n");
      Exec(Concatenation("cd ", pkgtmp, " ; cat listtextfiles.txt" ));
      Print("\n=====================end of the list of text files=======");
      Print("\n=====================binary files========================\n");
      Exec(Concatenation("cd ", pkgtmp, " ; cat listbinaryfiles.txt" ));
      Print("\n=====================end of the list of binary files=====");
      Print("\n=====================ignored files=======================\n");
      Exec(Concatenation("cd ", pkgtmp, " ; cat listignoredfiles.txt" ));
      Print("\n=====================end of the list of ignored files====\n");
      
      # NOW STORE THE PACKAGE IN THE REPOSITORY
      
      # remove files from the the previous version
      Exec( Concatenation( "rm -rf ", pkgreposdir, "/", pkgdirname, "/*" ) );
      # create 'pkg' subdirectory where the package will be stored
      Exec( Concatenation( "mkdir -p ", pkgreposdir, "/", pkgdirname, "/pkg" ) );
      # copy the PackageInfo.g file to the top level of the repository
      Exec( Concatenation( "cp -p -r ", pkgtmp, dnam, "/PackageInfo.g", " ", pkgreposdir, "/", pkgdirname, "/" ) );
      # get the lists of text/binary files
      Exec(Concatenation( "cp ", pkgtmp, "/listtextfiles.txt ", pkgreposdir, "/", pkgdirname, "/" ));
      Exec(Concatenation( "cp ", pkgtmp, "/listbinaryfiles.txt ", pkgreposdir, "/", pkgdirname, "/" ));

      # get the README file from package homepage (not from the archive!)
      if not IsBound( info.README_URL ) then
        Print("#   Error (", info.PackageName, "): README_URL not bound in the info file.\n");
      else 
        bname := Basename(info.README_URL);
        Exec(Concatenation("cd ", pkgtmp,"; rm -f ", bname, 
             "; wget --timeout=60 --tries=1 ", info.README_URL, " 2>> wgetlog"));
        if IsExistingFile(Concatenation(pkgtmp, "/", bname)) then
          Exec( Concatenation( "cp -p -r ", pkgtmp, "/", bname, " ", 
                                pkgreposdir, "/", pkgdirname, "/README.", nam ) );
        else
          Print("#   Error (", info.PackageName, "): could not get README file from\n   ", info.README_URL, "\n");
        fi;
      fi;
      
      # copy the package directory to the 'pkg' subdirectory of the repository
      # instead of doing this like in the next line
      # Exec( Concatenation( "cp -p -r ", pkgtmp, dnam, " ", pkgreposdir, "/", pkgdirname, "/pkg/" ) );
      # we are copying over the tar archive only those files which were selected 
      # during text/binary classification (to exclude files that should be ignored, e.g.
      # VCS files that may be occasionally wrapped into the package archive)
      Exec(Concatenation( 
        "cd ", pkgtmp, " ; ",
        "cat listtextfiles.txt listbinaryfiles.txt > listallfiles.txt ; ",
        "tar cf ", dnam, "-repack.tar -T listallfiles.txt ; ",
        "mv ", dnam, "-repack.tar ", pkgreposdir, "/", pkgdirname, "/pkg/ ; ", 
        "cd ", pkgreposdir, "/", pkgdirname, "/pkg/ ; ",
        "tar -xpf ", dnam, "-repack.tar ; ",
        "rm ", dnam, "-repack.tar ; " ) );
      
      # change to the repository and perform all version control magic 
      Exec ( Concatenation( "cd ", pkgreposdir, "/", pkgdirname, " ; ",
                            "hg addremove ; ",
                            "hg commit -m \"Version ", info.Version, ", ", info.Date, "\" ; ",
                            "hg tag Version-", info.Version ) );

      # THE NEW PACKAGE VERSION HAS BEEN STORED!
      Print("  ============================================\n");
    fi; # if package needs an update
  od; # end of loop over all packages
  return res;
end;

# This should be used carefully in manual mode only once:
# to populate repositories of package versions with backwards history
StoreLegacyPackageArchive := function( fullarchivename, pkgreposdir )

local pkgtmp, fname, ext, dnam, nam, info, pkgdirname, a;
        
# Create temporary directory and copy archive there
pkgtmp := DirectoryTemporary();
pkgtmp := Filename(pkgtmp,"");
Exec( Concatenation( "cp ", fullarchivename, " ", pkgtmp ));
fname:=Basename( fullarchivename );

# unpack the archive

if not IsLocalArchive( Concatenation(pkgtmp, fname) ) then
  Print("ERROR: archive contains path starting with / or containing ..\n");
  return;
fi;
      
Print("Unpacking ", fname, " ... \n");   
ext := fname{[Length(fname)-3..Length(fname)]};
if ext = "r.gz" then
  Exec(Concatenation("cd ", pkgtmp, ";gzip -dc ", fname, "|tar xpf - "));
elif ext = ".bz2" then
  Exec(Concatenation("cd ", pkgtmp, ";bzip2 -dc ", fname, "|tar xpf - "));
elif ext = ".zip" then
  Exec(Concatenation("cd ", pkgtmp, ";unzip -a ", fname ));
else
  Print("ERROR: unrecognized archive format ", fname, "\n");
  # return;
fi;
   
# name of unpacked directory (must no longer be 'nam')
dnam := Difference(FilesDir(pkgtmp, "d", 1), [pkgtmp]);
if Length(dnam) = 0 then
  Print("ERROR: could not unpack archive!\n");
  return;
else
  dnam := Basename(dnam[1]);
fi;
      
ClearPACKAGE_INFOS();
READPackageInfo(Concatenation(pkgtmp, dnam, "/PackageInfo.g"));
nam := NamesOfComponents(PACKAGE_INFOS);
if Length(nam) = 0 then
  Print( "IGNORED (bad version of PackageInfo.g)\n" );
  return;
fi;
nam := nam[1];
info := PACKAGE_INFOS.(nam);
pkgdirname := LowercaseString( NormalizedWhitespace( info.PackageName ) );

Print("Unpacked package ", info.PackageName, " ", info.Version, "\n");
      
if not ValidatePackageInfo( Concatenation(pkgtmp, dnam, "/PackageInfo.g")) then
  Print("  WARNING (", info.PackageName, "): validation of the info file not successful!!!\n");
fi;

# need to find out the text files
Print("Finding text files  . . .\n");
  PrintTo( Concatenation(pkgtmp, "patternstextbinary.txt" ), "#Autogenerated by GAP\n" );
Exec( Concatenation ( "cd ", pkgtmp, " ; touch patternstextbinary.txt" ) );

if Number( [IsBound(info.TextFiles), 
            IsBound(info.BinaryFiles), 
            IsBound(info.TextBinaryFilesPatterns) ], a -> a=true ) > 1 then
  Print("  WARNING (", info.PackageName, 
        "): do not use more than one of TextFiles, BinaryFiles, TextBinaryFilesPatterns\n");
  Print("          The superfluous components will be ignored.\n");
fi;           

if IsBound(info.TextFiles) then
  Print("  using ", info.TextFiles, " from PackageInfo.g as text files \n");
  AppendTo( Concatenation(pkgtmp, "patternstextbinary.txt" ), "# Autoextended by GAP\n" );
  for a in info.TextFiles do
    AppendTo( Concatenation(pkgtmp, "patternstextbinary.txt" ), "T", a, "\n" );
  od;
elif IsBound(info.BinaryFiles) then
  Print("  using ", info.BinaryFiles, " from PackageInfo.g as binary files \n");
  AppendTo( Concatenation(pkgtmp, "patternstextbinary.txt" ), "# Autoextended by GAP\n" );
  for a in info.BinaryFiles do
    AppendTo( Concatenation(pkgtmp, "patternstextbinary.txt" ), "B", a, "\n" );
  od;
elif IsBound(info.TextBinaryFilesPatterns) then
  Print("  using ", info.TextBinaryFilesPatterns, " from PackageInfo.g to set text/binary patterns \n");
  AppendTo( Concatenation(pkgtmp, "patternstextbinary.txt" ), "# Autoextended by GAP\n" );
  for a in info.TextBinaryFilesPatterns do
    AppendTo( Concatenation(pkgtmp, "patternstextbinary.txt" ), a, "\n" );
  od;  
fi;
      
# classify text/binary files with Max's script classifyfiles.py
Exec( Concatenation (
    "cp ../classifyfiles.py ", pkgtmp, "/ ; ",
    "cp ../patternscolorpkg.txt ", pkgtmp, "/patternscolor.txt ;",
    "cat ../patternstextbinary.txt >> ", pkgtmp, "/patternstextbinary.txt ;",
    "echo \"B*\" >> ", pkgtmp, "/patternstextbinary.txt ; ",
    "cd ", pkgtmp, " ; ",
    "python ./classifyfiles.py ", dnam ) );           
 
Print("\n=====================text files==========================\n");
Exec(Concatenation("cd ", pkgtmp, " ; cat listtextfiles.txt" ));
Print("\n=====================end of the list of text files=======");
Print("\n=====================binary files========================\n");
Exec(Concatenation("cd ", pkgtmp, " ; cat listbinaryfiles.txt" ));
Print("\n=====================end of the list of binary files=====");
Print("\n=====================ignored files=======================\n");
Exec(Concatenation("cd ", pkgtmp, " ; cat listignoredfiles.txt" ));
Print("\n=====================end of the list of ignored files====\n");
      
# NOW STORE THE PACKAGE IN THE REPOSITORY
      
# remove the previous version
Exec( Concatenation( "rm -rf ", pkgreposdir, "/", pkgdirname, "/*" ) );
# create 'pkg' subdirectory where the package will be stored
Exec( Concatenation( "mkdir -p ", pkgreposdir, "/", pkgdirname, "/pkg" ) );
# copy the PackageInfo.g file to the top level of the repository
Exec( Concatenation( "cp -p -r ", pkgtmp, dnam, "/PackageInfo.g", " ", pkgreposdir, "/", pkgdirname, "/" ) );
# get the lists of text/binary files
Exec(Concatenation( "cp ", pkgtmp, "/listtextfiles.txt ", pkgreposdir, "/", pkgdirname, "/" ));
Exec(Concatenation( "cp ", pkgtmp, "/listbinaryfiles.txt ", pkgreposdir, "/", pkgdirname, "/" ));

# copy the package directory to the 'pkg' subdirectory of the repository
# instead of doing this like in the next line
# Exec( Concatenation( "cp -p -r ", pkgtmp, dnam, " ", pkgreposdir, "/", pkgdirname, "/pkg/" ) );
# we are copying over the tar archive only those files which were selected 
# during text/binary classification (to exclude files that should be ignored, e.g.
# VCS files that may be occasionally wrapped into the package archive)
Exec(Concatenation( 
"cd ", pkgtmp, " ; ",
"cat listtextfiles.txt listbinaryfiles.txt > listallfiles.txt ; ",
"tar cf ", dnam, "-repack.tar -T listallfiles.txt ; ",
"mv ", dnam, "-repack.tar ", pkgreposdir, "/", pkgdirname, "/pkg/ ; ", 
"cd ", pkgreposdir, "/", pkgdirname, "/pkg/ ; ",
"tar -xpf ", dnam, "-repack.tar ; ",
"rm ", dnam, "-repack.tar ; " ) );
      
# change to the repository and perform all version control magic 
Exec ( Concatenation( "cd ", pkgreposdir, "/", pkgdirname, " ; ",
                      "hg addremove ; ",
                      "hg commit -m \"Version ", info.Version, ", ", info.Date, "\" ; ",
                      "hg tag Version-", info.Version ) );
# THAT'S ALL FOLKS! THE NEW PACKAGE VERSION HAS BEEN STORED!
end;

 
MergePackages := function(pkgdir, pkgreposdir, tmpdir, archdir, webdir, parameters)
# This function is called from the 'mergePackages' script 
# with the following arguments: 
# PkgCacheDir, PkgReposDir, PkgMergeTmpDir, PkgMergedArchiveDir, PkgWebFtpDir, true
  local mergedir, pkgs, basepkgs, textfilesmerge, nam, info, tf, 
        fname, fun, allfiles, allformats, pkg, timestamp, fmt, fn_targzArch,
        default, specific, t, s, revision, tag, old, fn, onlyneeded, suffix;

  # Parsing parameters of packages combination to be assembled
 
  default := "tip";    # by default, take latest version of each package
  allformats := false; # by default, do not wrap individual package archives
  onlyneeded :=false;  # by default, wrap all packages
  specific := [];      # list to collect specific requirements for packages
  if Length( parameters ) > 0 then
    # package update mechanism uses lowercase names for directories
    parameters := LowercaseString( parameters );
    # spaces only to split keywords and different packages
    # DO NOT put spaces around '=' specifying requirements
    parameters := SplitString( parameters, " ", " ");
    # we allow either keywords or specifying package version explicitly
    if not ForAll( parameters, s -> s in [ "all", "only", "tip", "latest", "stable"] or '=' in s ) then
      Print("ERROR: mergePackages must be called in one of the following ways:\n",
            "1) without arguments\n",
            "2) with keyword 'all' to wrap individual package archives in all formats\n",
            "3) with one of keywords 'tip', 'latest' (synonym of 'tip') or 'stable'\n",
            "4) with specifications of the form pkgname=tip|latest|stable|version|no\n",
            "5) with keyword 'only' to wrap merged archive only with packages specified as in (4)\n",
            "6) with a combination of arguments as in (2) and (3) above\n\n");
      return;
    fi;
    if "all" in parameters then
      allformats := true;
    fi;
    if "only" in parameters then
      onlyneeded := true;
    fi;
    # check the use of keywords
    t := Filtered( parameters, s -> not '=' in s and not s in ["all","only"] );
    if Length( t ) > 1 then
      Print("ERROR: only one of 'stable', 'tip' or 'latest' (synonym of 'tip') \n",
            "       may be specified as default \n\n");
      return;   
    elif Length( t ) = 1 then
      default := t[1];
      if default="latest" then
        default:="tip";
      fi;  
    fi;
    t := Filtered( parameters, s -> '=' in s);
    specific := List( t, s -> SplitString( s, "=" ) );
    # now `specific` is a list of pairs [<packagename>,<requirement>]
  fi;

  Print("Preparing to wrap package archive with the following settings:\n",
        "Wrap individual package archives : ", allformats, "\n",
        "Use only specified packages      : ", onlyneeded, "\n",
        "Default package version          : ", default, "\n",
        "Specific requirements            : ", specific, "\n");
 
  # get the list of packages which are known to the package update system
  pkgs := Difference(FilesDir(pkgreposdir, "d", 1), [pkgreposdir]);
  basepkgs := List( pkgs, Basename );
  
  if not ForAll( specific, s -> s[1] in basepkgs ) then
    Print("ERROR: nothing known about package(s) ", 
          Filtered( specific, s -> not s[1] in basepkgs ), "\n",
          "Check that the package is added for the redistribution,\n",
          "its name is spelled correctly and that the convention\n",
          "'pkgname=tip|latest|stable|version|no' is followed\n\n");
    return; 
  fi;

  if tmpdir[Length(tmpdir)] <> '/' then
    tmpdir := Concatenation(tmpdir, "/");
  fi;
  if pkgdir[Length(pkgdir)] <> '/' then
    pkgdir := Concatenation(pkgdir, "/");
  fi;
  
  mergedir := Concatenation(tmpdir, "merge/");
  Exec(Concatenation("rm -rf ", mergedir));
  Exec(Concatenation("mkdir -p ", mergedir));
  
  textfilesmerge := [];

  for pkg in pkgs do # enumerate all packages

    # we update to the tip before doing any other actions to ensure that 
    # in case of any errors the latest version of the package will be used
    Exec( Concatenation( "cd ", pkg, " ; hg update -r tip" ));
    # TODO: while we are at the tip, figure out what's the version here.
    # Then when requested stable, we may report if it is latest or not
    
    # now some analysys and update to the version needed
    t := Filtered( specific, s -> s[1]=Basename(pkg) );
    if Length(t) = 0 then
      revision:=default;
    else 
      if Length(t) > 1 then
        Print("WARNING: more than one requirement specified:\n", t, "\n",
              "         but only the first one will be used\n");
      fi;
      # revision must be a version number of one of:
      # 'tip', 'latest' (synonym of 'tip'), 'stable' or 'no'
      revision:=t[1][2];
      if default="latest" then
        default:="tip";
      fi;        
    fi;    
    
    if revision="no" or ( onlyneeded and not Basename(pkg) in List( specific, s -> s[1] ) ) then
      Print("Skipping ", pkg, "\n");
      continue;
    fi;  
    
    if revision = "stable" then
      tag := revision;
    elif revision in ["tip","latest"] then
      tag := "tip";
    else # assuming that explicit version number is specificed
      tag := Concatenation( "Version-", revision );
    fi;  
    
    Print("    requesting version ", revision, " ... \n");
    Exec( Concatenation( "cd ", pkg, " ; hg update -r ", tag ));

    # read info file and check the version number in it
    ClearPACKAGE_INFOS();
    READPackageInfo(Concatenation(pkg, "/", "PackageInfo.g"));
    nam := NamesOfComponents(PACKAGE_INFOS);
    if Length(nam) = 0 then
      Print("Skipping ", pkg, "\n");
      continue;
    fi;
    nam := nam[1];
    info := PACKAGE_INFOS.(nam);
    if not revision in ["tip","latest","stable"] then
      if revision <> info.Version then
        Print("ERROR: can not find version ", revision, " of ", info.PackageName, "\n");
      fi;
    fi;
    Print("Package ", info.PackageName, ": requested ", 
          revision, ", retrieved version ", info.Version, "\n");
    tf := textfilesmerge;
    if not IsBound(info.ArchiveURL) then
      continue;
    fi;

    # Touch all files to update their modification time
    Exec(Concatenation("cd ", pkg, " ; find pkg -exec touch -r \"listtextfiles.txt\" {} \\;" ) );

    # To copy the package from the repository to the destination, use
    Exec(Concatenation("cd ", pkg, " ; cp -p -r pkg/* ", mergedir ));
    # TODO: on Linux, use hard links instead of copying all files

    # and copy files with lists of text files and binary files
    Exec( Concatenation("cp -p ", pkg, "/listtextfiles.txt ", mergedir, nam, ".txtfiles"));
    Exec( Concatenation("cp -p ", pkg, "/listbinaryfiles.txt ", mergedir, nam, ".binfiles"));
    
    # if called with 'all', will also wrap individual archives for redistribution, 
    # otherwise will only wrap the merged archive
    # TODO: shall we forbid 'all' when not called with 'stable'?
    if allformats then 
    # wrap indvidual package arhives in all redistributed formats
      fname  := Basename( info.ArchiveURL );
      # if the package provides archives named 'version.format',
      # we rename them to 'packagename-version.format'
      if fname[1] in "0123456789" then
        fname:=Concatenation( info.PackageName, "-", fname );
      fi;
      Exec(Concatenation("cd ", mergedir, " ; ",
            "cat ", nam, ".txtfiles ", nam, ".binfiles > ", nam, ".allfiles"));
      Print("  creating ",fname,".zip\n");
      Exec(Concatenation("cd ", mergedir,"; rm -f ", fname, ".zip ; ",
            "cat ", nam, ".allfiles | zip -v -9 ", fname, ".zip -@ > /dev/null"));
      Print("  creating ",fname,"-win.zip\n");
      Exec(Concatenation("cd ", mergedir,"; rm -f ", fname, "-win.zip ; ",
            "cat ", nam, ".binfiles | zip -v -9 ", fname, "-win.zip -@ > /dev/null; ",
            "cat ", nam, ".txtfiles | zip -v -9 -l ", fname, "-win.zip -@ > /dev/null "));
      Print("  creating ",fname,".tar\n");
      Exec(Concatenation("cd ", mergedir, " ; ",
            "tar cpf ", fname, ".tar -T ", nam, ".allfiles ; "));
      Print("  creating ",fname,".tar.gz\n");
      Exec(Concatenation("cd ", mergedir, " ; ",
            "cp ", fname, ".tar ", fname, ".tar.X ; ", 
            "gzip -9 ", fname, ".tar ; "));
      Print("  creating ",fname,".tar.bz2\n");
      Exec(Concatenation("cd ", mergedir, " ; ",
            "mv -f ", fname, ".tar.X ", fname, ".tar ; ",
            "bzip2 -9 ", fname, ".tar" ));
               
      # copy to Web and move archives
      for fmt in [ ".tar.gz", ".tar.bz2", "-win.zip", ".zip" ] do
        if not IsExistingFile(Concatenation(webdir, "/ftpdir/",
          fmt{[2..Length(fmt)]}, "/packages/", fname, fmt)) then
          # first delete old ones from ftp dir
          old := List(FilesDir(pkg, "f", 1), Basename);
          old := Filtered(old, a-> Length(a)>=Length(fmt) and
                 a{[Length(a)-Length(fmt)+1..Length(a)]} = fmt);
          for fn in old do
            Exec(Concatenation("rm -f ", webdir, "/ftpdir/", 
                 fmt{[2..Length(fmt)]}, "/packages/", fn));
          od;
          if IsExistingFile(Concatenation(mergedir,"/",fname,fmt)) then
            Exec(Concatenation("cd ", mergedir,"; mv -f ", fname, fmt, " .."));
          fi;
          Exec(Concatenation("cd ", mergedir, "/.. ; cp -f ", fname, fmt,
                        " ", webdir, "/ftpdir/", fmt{[2..Length(fmt)]},
                        "/packages/")); 
        fi;
      od;  
      Exec( Concatenation( "cd ", mergedir, " ; rm *.allfiles") );
    fi; # if allformats
     
  od; # end of the loop over all packages

  if allformats then
    Print("Completed wrapping individual package archives, stopping now ... \n");
    return;
  fi;
  
  # now create the merged tar.gz archive
  # (just this, no others any more)
  fun := function(pkgdir, dir, fn, textfiles)
    local a;
    ## local allfiles;
    Exec(Concatenation("cd ", dir, "; tar cpf ../", fn, ".tar * ; cd .. ; ",
         " gzip -9 ", fn, ".tar ; " ));
  end; 

  timestamp := StringCurrentTime();
  while Length(timestamp) > 0 and timestamp[Length(timestamp)] = '\n' do
    Unbind(timestamp[Length(timestamp)]);
  od;

  if onlyneeded then
    suffix := "required-";
  else
    suffix := "";
  fi;

  Print("Wrapping metainformation archive ...\n");
   
  Exec( Concatenation( 
    "cd ", mergedir, " ; ", 
    "cat *.txtfiles > metainfotxtfiles-", suffix, timestamp, ".txt ; ",
    "cat *.binfiles > metainfobinfiles-", suffix, timestamp, ".txt ; ",
    "rm *.txtfiles ; ",
    "rm *.binfiles ; ",
    "rm -rf *.tar.gz *.tar.bz2 *.zip ; ",
    "ls metainfo* | zip -q metainfopackages-", suffix, timestamp, " -@" ) );  
    
  # move metainfo archive to the archive collection and then cleanup
  Exec(Concatenation("cd ", archdir, "; mkdir -p old; rm -rf old/* ; ",
       "touch metainfopackages*; mv metainfopackages* old ; ",
       "cp -f ", tmpdir, "/merge/metainfopackages*.zip ", archdir, 
       "; rm -f ", tmpdir, "/merge/metainfo*",
       "; rm -f ", webdir, "/ftpdir/*/metainfo*"));
 
  Print("Wrapping merged packages archive ...\n");
  fun(pkgdir, mergedir, Concatenation("packages-", suffix, timestamp), textfilesmerge);

  # TODO: change the location of the merged archive - it's not going public

  Print("Archiving/deleting older merged package archives...\n");
  Exec(Concatenation("cd ", archdir, "; mkdir -p old; ",
       "touch packages-*; mv packages-* old; cp -f ", tmpdir, "/packages-* ",
       archdir, "; rm -f ", webdir, "/ftpdir/*/packages-*"));

  Print("Copying new merged package archive ...\n");
  for fmt in [ ".tar.gz" ] do # no merged ".tar.bz2", "-win.zip"
    Exec(Concatenation("mv -f ", tmpdir, "/packages-*", fmt, " ", webdir, 
         "/ftpdir/", fmt{[2..Length(fmt)]}, "/"));
  od;
       
end;


MarkStableRevisions := function(pkgreposdir, parameters)
local default, s, t, pkgname, pair, revision, pkgdir, tag, nam, info;
  if Length( parameters ) > 0 then
    parameters := LowercaseString( parameters );
    parameters := SplitString( parameters, " ", " ");
    if not ForAll( parameters, s -> '=' in s ) then
      Print("ERROR: markStableRevisions must be called with a list\n",
            "of specifications of the form pkgname=tip|latest|version|\n");
      return;
    fi;
    parameters := List( parameters, s -> SplitString( s, "=" ) );
  fi;
  Print("### Preparing to mark the following revisions as stable:\n", parameters, "\n");
  for pair in parameters do
    Print("*** Marking revision ", pair[2], " of ", pair[1], " package ...\n" );
    pkgname := LowercaseString(pair[1]);
    revision := pair[2];
    pkgdir := Concatenation( pkgreposdir, "/", pkgname );
    if IsExistingFile( pkgdir ) then
      if revision in ["tip","latest"] then
        tag := "tip";
      else # assuming that explicit version number is specified
        tag := Concatenation( "Version-", revision );
      fi;     
      Print("    updating to the latest revision ...\n");
      Exec( Concatenation( "cd ", pkgdir, " ; hg update -r tip" ));
      Print("    requesting revision ", revision, " ... \n");
      Exec( Concatenation( "cd ", pkgdir, " ; hg update -r ", tag ));

      # read info file and check the version number in it
      ClearPACKAGE_INFOS();
      READPackageInfo(Concatenation(pkgdir, "/", "PackageInfo.g"));
      nam := NamesOfComponents(PACKAGE_INFOS);
      if Length(nam) = 0 then
        Print("Skipping ", info.PackageName, ", can't read PackageInfo.g\n");
        continue;
      fi;
      nam := nam[1];
      info := PACKAGE_INFOS.(nam);
      if not revision in ["tip","latest"] then
        if revision <> info.Version then
          Print("ERROR: can not find version ", revision, " of ", info.PackageName, ", skipping ...\n");
          continue;
        fi;
      fi;
      Print("    retrieved ", info.PackageName, ", version ", info.Version, "\n");
      Print("    bookmarking ", info.PackageName, ", version ", info.Version, " as stable\n");
      Exec( Concatenation( "cd ", pkgdir, " ; hg bookmark -i -f stable -r Version-", info.Version ));
    else
      Print("Nothing known about the package ", pair[1], "\n");
    fi;
  od;  
  Print("DONE!\n");
end;


# Marking all latest versions of packages as stable
# Use with care - this should be done only once at the initialisation
MarkAllLatestStable := function(pkgreposdir)
local pkgs, pkg;
pkgs := Difference(FilesDir(pkgreposdir, "d", 1), [pkgreposdir]);
for pkg in pkgs do
  MarkStableRevisions( pkgreposdir, Concatenation( Basename(pkg), "=latest" ) );
od;
end;


# The 2nd argument is the name of the archive with the timestamp without 
# extension, e.g. gap4r5p4_2012_06_04-23_02. For each package, tags its 
# stable version with the given tag. You must ensure that it matches 
# current stable versions.
markAllStableWithTimestamp := function( pkgreposdir, timestamp )
local pkgs, res, pkgdir, info, getInfo, ver, i, j, m, x;

getInfo:=function( pkgdir )
local nam;
ClearPACKAGE_INFOS();
READPackageInfo(Concatenation(pkgdir, "/", "PackageInfo.g"));
nam := NamesOfComponents(PACKAGE_INFOS);
if Length(nam) = 0 then
  return fail;
else
  nam := nam[1];
  return PACKAGE_INFOS.(nam);
fi;
end;

pkgs := Difference(FilesDir(pkgreposdir, "d", 1), [pkgreposdir]);
res:=[ [ "Package name", "Latest", "Date", "Stable", "Date" ]];
Print("Marking stable revisions with ", timestamp,"\n");
for pkgdir in pkgs do
  Print("Marking ", pkgdir, "\n");
  Exec( Concatenation( "cd ", pkgdir, " ; hg update -r tip" ));
  info := getInfo( pkgdir );
  ver := [ info.PackageName, info.Version, info.Date ];
  Exec( Concatenation( "cd ", pkgdir, " ; hg update -r stable" ));
  info := getInfo( pkgdir );
  if info.Version <> ver[2] then
    Append( ver, [ info.Version, info.Date ] );
  else
    Append( ver, [ "*", " " ] );
  fi;
  Exec( Concatenation( "cd ", pkgdir, " ; hg bookmark -i ", timestamp, " -r Version-", info.Version ));
  Exec( Concatenation( "cd ", pkgdir, " ; hg update -r tip" ));
  Add( res, ShallowCopy( ver ) );  
od;

# post-processing for pretty-printing the report
for j in [1..5] do
  m := Maximum( List( res, x -> Length(x[j]) ) );
  for x in res do
    Append( x[j], ListWithIdenticalEntries( m-Length(x[j]), ' ' ) );
  od;
od;  
Print("=======================================================================\n");
for i in [1..Length(res)] do
  for j in [1..Length(res[i])] do
    Print( res[i][j], " | ");
  od;
  Print("\n");
od;
Print("=======================================================================\n");
end;



ReportPackageVersions:=function( pkgreposdir )
local pkgs, pkgdir, info, getInfo, res, ver, i, j, m, x, outstr, out, proc;

getInfo:=function( pkgdir )
local nam;
ClearPACKAGE_INFOS();
READPackageInfo(Concatenation(pkgdir, "/", "PackageInfo.g"));
nam := NamesOfComponents(PACKAGE_INFOS);
if Length(nam) = 0 then
  return fail;
else
  nam := nam[1];
  return PACKAGE_INFOS.(nam);
fi;
end;

pkgs := Difference(FilesDir(pkgreposdir, "d", 1), [pkgreposdir]);
res:=[ [ "Package name", "Latest", "Date", "Stable", "Date" ]];

for pkgdir in pkgs do
Print("*** Checking ", pkgdir, "\n" );

  ver:=[];

  Print("# checking out the latest version ...\n");
  Exec( Concatenation( "cd ", pkgdir, " ; hg update -r tip" ));
  info := getInfo( pkgdir );
  if info = fail then
    Print("# Skipping ", pkgdir, "\n");
    continue;
  fi;
  Print("* latest version ", info.Version, " (", info.Date, ")\n");

  ver := [ info.PackageName, info.Version, info.Date ];
  
  # checking if the stable bookmark is not yet set
  # (in which case there should be no bookmarks set at all)
  outstr := "";
  out := OutputTextString(outstr,false);
  proc := Process(
    Directory( pkgdir ),
    Filename( DirectoriesSystemPrograms(), "hg" ),
    InputTextNone(),
    out,
    ["bookmarks"] );
  CloseStream(out);

  # This is quite fragile, since it depends on this output from Mercurial.
  # If this will be changed, packages without stable bookmarks may appear
  # to be stable
  if NormalizedWhitespace(outstr) <> "no bookmarks set" then

    Print("# checking out the stable version ... \n");
    Exec( Concatenation( "cd ", pkgdir, " ; hg update -r stable" ));
    info := getInfo( pkgdir );
    Print("* stable version ", info.Version, " (", info.Date, ")\n");

    # return back to the tip of the repository
    Exec( Concatenation( "cd ", pkgdir, " ; hg update -r tip" ));

    if info.Version <> ver[2] then
      Append( ver, [ info.Version, info.Date ] );
    else
      Append( ver, [ "*", " " ] );
    fi;

  else
    Append( ver, [ "---", " " ] );
  fi;    

  Add( res, ShallowCopy( ver ) );  

od;

# post-processing for pretty-printing
for j in [1..5] do
  m := Maximum( List( res, x -> Length(x[j]) ) );
  for x in res do
    Append( x[j], ListWithIdenticalEntries( m-Length(x[j]), ' ' ) );
  od;
od;  
Print("=======================================================================\n");
for i in [1..Length(res)] do
  for j in [1..Length(res[i])] do
    Print( res[i][j], " | ");
  od;
  Print("\n");
od;
Print("=======================================================================\n");
end;


# returns list of [dirname, bookname] of updated packages
UpdatePackageDoc := function(pkgdir, pkgdocdir)
  local pkgs, res, nam, info, books, url, fname, pkgtmp, fmt, pkg, 
        b, pkgarch, a, dname, compactname, c;
  # package dirs
  pkgs := Difference(FilesDir(pkgdir, "d", 1), [pkgdir]);
  res := [];
  for pkg in pkgs do
    ClearPACKAGE_INFOS();
    READPackageInfo(Concatenation(pkg, "/PackageInfo.g"));
    nam := NamesOfComponents(PACKAGE_INFOS);
    if Length(nam) = 0 then
      continue;
    fi;
    nam := nam[1];
    info := PACKAGE_INFOS.(nam);
    Print(info.PackageName, ":\n");
    
    pkgtmp := Concatenation(pkg, "/pkg");
    dname := NormalizedWhitespace(
               StringSystem("sh", "-c", Concatenation("cd ", pkgtmp, "; ls")));
    Exec( Concatenation( "mkdir -p ", pkgdocdir, "/", dname )); 
    Exec(Concatenation("cp -p ", pkg, "/README.* ", pkgdocdir, "/", dname, "/" ));
                               
    if not IsBound(info.PackageDoc) then
      Print("# Warning (", info.PackageName, "): no PackageDoc component!\n");
      continue;
    fi;
    # check if one or several books
    if IsList(info.PackageDoc) then
      books := info.PackageDoc;
    else
      books := [info.PackageDoc];
    fi;
    
    for b in books do
      # Should the documentation be taken from the package release, 
      # or is there a separate archive with the package documentation?
      if IsBound(b.ArchiveURLSubset) then
        # Get all manuals from the package release stored in the repository
        for a in b.ArchiveURLSubset do
          if IsExistingFile( Concatenation( pkgtmp, "/", dname, "/", a ) ) then
            # whether a is a directory name or (rarely) a filename, e.g. doc/manual.pdf?
            if Basename(a)=a then
            # directory name or a file in the current directory
            Exec(Concatenation("cd ", pkgtmp, "/", dname, " ; ",
                               "cp -p -fr ", a, " ", pkgdocdir, "/", dname ));
            else
            Exec(Concatenation("cd ", pkgtmp, "/", dname, " ; ",
                               "mkdir -p ", pkgdocdir, "/", dname, "/", Dirname(a), " ; ",
                               "cp -p -fr ", a, " ", pkgdocdir, "/", dname, "/", Dirname(a), "/" ));
            fi;
          else
            Print("WARNING: package ", info.PackageName, ", book ", b.BookName, 
                  " has no subdirectory ", dname, "/", a, "\n",
                  "         but has ArchiveURLSubset=", b.ArchiveURLSubset, "\n" );
          fi;
          # TODO: can we detect whether there is a GAPDoc manual without .css file?
          # We may try some heuristics as below, but false alarms are annoying.
          #if IsExistingFile( Concatenation( pkgtmp, "/", dname, "/", a, "/manual.css" ) ) then 
          #  if not ( IsExistingFile( Concatenation( pkgtmp, "/", dname, "/", a, "/manual.xml" ) ) or
          #           IsExistingFile( Concatenation( pkgtmp, "/", dname, "/", a, "/", a, ".xml" ) ) or
          #           IsExistingFile( Concatenation( pkgtmp, "/", dname, "/", a, "/", b.BookName, ".xml" ) ) or
          #           IsExistingFile( Concatenation( pkgtmp, "/", dname, "/", a, "/", pkg, ".xml" ) ) ) then
          #    Print("WARNING: package ", info.PackageName, ", book ", b.BookName, "\n",
          #          " probably has a GAPDoc-based manual with missing .css file\n",
          #          "Check the content of the directory ", dname, "/", a, " below:\n" );
          #      Exec( Concatenation( "cd ", pkgtmp, "/", dname, "/", a , " ; ls *.xml *.css" ) );
          #  fi;    
          #fi;
        od;
        Add(res, [nam, b.BookName]);                           
      elif IsBound(b.Archive) then
        # Use the separate archive with the package documentation
        url := b.Archive;
        fname := Basename(url);
        # check if it is already in the local collection
        if IsExistingFile(Concatenation(pkgdir, "/", nam, 
                          "/", fname)) then
          Print("  doc archive ", b.BookName, " is up-to-date.\n");
          continue;
        else
          Print("  updating help book ", b.BookName, " from separate archive.\n");
        fi;
         
        # ok, so we have to get the archive
        Add(res, [nam, b.BookName]);
        pkgtmp := DirectoryTemporary();
        pkgtmp := Filename(pkgtmp,"");
        Exec(Concatenation("cd ", pkgtmp, ";wget --timeout=60 --tries=1 ", 
             url, " 2>> wgetlog"));
        fmt := url{[Length(url)-3..Length(url)]};
        # for SECURITY: don't allow unpacking of ../.... or /... files 
        if not IsLocalArchive(Concatenation(pkgtmp, fname)) then
          Print("    REJECTING book archive ", [nam, b.BookName], " because ",
                "of non-allowed paths!!!\n");
        fi;
        Print("  unpacking new documentation ", fname, "\n");
        if fmt = "r.gz" then
          Exec(Concatenation("cd ", pkgtmp, ";gzip -dc ", fname, " |tar xpf - "));
        elif fmt = ".bz2" then
          Exec(Concatenation("cd ", pkgtmp, ";bzip2 -dc ", fname, " |tar xpf - "));
        elif fmt = ".zip" then
          Exec(Concatenation("cd ", pkgtmp, ";unzip -a ", fname));
        else
          Error("(", info.PackageName, "): no recognized archive format: ", fmt);
        fi;
        # we assume that package directory is lower case of package name
        dname := nam;
        # move to web dir and to archives
        Exec(Concatenation("cd ", pkgtmp, "; rm -f wgetlog ; ",
                           "mkdir -p ", pkgdocdir, "/", dname, 
                           "; cp -p -fr * ", pkgdocdir, "/", dname,  
                           "; cp -p -fr * ..; rm -rf *"));
        else
        dname := nam;
        Print("   WARNING (", info.PackageName, "): No package documentation specified!\n");
      fi;
    od;
  od;
  return res;
end;



# Write the <pkgname>.mixer file for a package
# args: info[, webdir]                    default for webdir is "../web"
AddHTMLPackageInfo := function(arg)
  local info, webdir, NameChunk, nam, res, auth, maint, dep, s, books, 
        manlink, bnam, arch, dname, fn, a, i, p, ext;
  info := arg[1];
  if Length(arg)>1 then
    webdir := arg[2];
  else
    webdir := "../web";
  fi;
  NameChunk := function(r)
    local res;
    res := Concatenation(r.FirstNames, " ", r.LastName);
    # we add link to webpage, if available, or a mailto link, if email
    # address available
    if IsBound(r.WWWHome) then
      res := Concatenation("<a href=\"", r.WWWHome, "\">", res, "</a>"); 
    elif IsBound(r.Email) then
      res := Concatenation("<a href=\"mailto:", r.Email, "\">", res, "</a>"); 
    fi;
    return res;
  end;

  # directory name
  nam := NormalizedWhitespace(LowercaseString(info.PackageName));
  
  res := Concatenation("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n",
         "<mixer template=\"gw.tmpl\">\n");
  # header line with link to package home page
  Append(res, Concatenation("<mixertitle><mixer var=\"GAP\"/> package ", 
         info.PackageName, 
         "</mixertitle>\n\n"));

  if IsBound(info.Subtitle) then
    Append(res, Concatenation("<h2>", info.Subtitle, "</h2>\n"));
  fi;
  if not IsBound(info.PackageWWWHome) then
    info.PackageWWWHome := "n.a.";
  fi;
  Append(res, Concatenation("<p class=\"homelink\">[<a href=\"",
         info.PackageWWWHome, "\">WWW homepage</a>]</p>\n"));
  # author(s)/maintainer(s) list, possibly with links
  auth := []; 
  maint := [];
  if not IsBound(info.Persons) then
    info.Persons := [];
  fi;
  for a in info.Persons do
    if IsBound(a.IsAuthor) and a.IsAuthor = true then
      Add(auth, a);
    elif IsBound(a.IsMaintainer) and a.IsMaintainer = true then
      Add(maint, a);
    fi;
  od;
  if Length(auth) > 0 then
    Append(res, "<h4>Author");
    if Length(auth) > 1 then
      Add(res, 's');
    fi;
    Append(res, "</h4>\n<p>");
    Append(res, NameChunk(auth[1]));
    for i in [2..Length(auth)]  do
      Append(res, Concatenation(", \n",  NameChunk(auth[i])));
    od;
    Append(res, "</p>\n");
  fi;
  if Length(maint) > 0 then
    Append(res, "<h4>Maintainer");
    if Length(maint) > 1 then
      Add(res, 's');
    fi;
    Append(res, "</h4>\n<p>");
    Append(res, NameChunk(maint[1]));
    for i in [2..Length(maint)]  do
      Append(res, Concatenation(", \n",  NameChunk(maint[i])));
    od;
    Append(res, "\n</p>\n");
  fi;
  
  # summary
  if not IsBound(info.AbstractHTML) then
    info.AbstractHTML := "";
  fi;
  Append(res, Concatenation("<h4>Short Description</h4>\n<p><![CDATA[", 
              info.AbstractHTML, "]]>\n</p>\n"));

  # hook for additional infos not produced here            
  Append(res, "\n<mixer part=\"extra\" needed=\"no\"/>\n\n");

  # version / date
  if not IsBound(info.Version) then
    info.Version := "unknown";
  fi;
  if not IsBound(info.Date) then
    info.Date := "unknown";
  fi;
  Append(res, Concatenation("<h4>Version</h4>\n<p> Current version number ",
                 info.Version, 
                 " &nbsp;&nbsp;(Released  ", info.Date, ")\n</p>\n"));
  # SuggestUpgrades  entry
  info.SuggestUpgradesEntry := Concatenation("[ \"", info.PackageName,
       "\", \"", info.Version, "\" ], ");
  # status
  Append(res, Concatenation("<h4>Status</h4>\n<p>",
              info.Status, "\n"));
  # communicated by ...
  if IsBound(info.CommunicatedBy) then
    Append(res, Concatenation("&nbsp;&nbsp; (communicated  by ",
                   info.CommunicatedBy,
                   ", \n"));
    if not IsBound(info.AcceptDate) then
      info.AcceptDate := "unknown";
    fi;
    Append(res, Concatenation("accepted ", info.AcceptDate, ")\n"));
  fi;
  Append(res, "</p>\n");

  # dependencies
  if IsBound(info.Dependencies) then
    dep := info.Dependencies;
    Append(res, "<h4>Dependencies</h4>\n<p>\n");
    if not IsBound(dep.GAP) then
      dep.GAP := "unknown";
    fi;
    Append(res, Concatenation("<span class='pkgname'>GAP</span> ",
           "version: ", dep.GAP, "<br />"));
    if IsBound(dep.NeededOtherPackages) and 
                         Length(dep.NeededOtherPackages) > 0 then
      Append(res, "Needed other packages: ");
      for p in dep.NeededOtherPackages do
        Append(res, Concatenation(p[1], "(", p[2], "), "));
      od;
      Append(res, "<br />");
    fi;
    if IsBound(dep.SuggestedOtherPackages) and
                          Length(dep.SuggestedOtherPackages) > 0 then
      Append(res, "Suggested other packages: ");
      for p in dep.SuggestedOtherPackages do
        Append(res, Concatenation(p[1], "(", p[2], "), "));
      od;
      Append(res, "<br />");
    fi;
    if IsBound(dep.ExternalConditions) and
                           Length(dep.ExternalConditions) > 0 then
      Append(res, "External needs: ");
      s := List(dep.ExternalConditions, function(a)
        if IsString(a) then 
          return a;
        else
          return Concatenation("<a href='", String(a[2]), "'>", String(a[1]),
                 "</a>");
        fi;
      end);
      Append(res, JoinStringsWithSeparator(s, ",\n"));
    fi;
    Append(res,"\n</p>\n");
  fi;
 
  # online documentation
  if not IsBound(info.PackageDoc) then
    info.PackageDoc := [];
  fi;
  if not IsList(info.PackageDoc) then
    books := [info.PackageDoc];
  else
    books := info.PackageDoc;
  fi;
  # directory name of unpacked archive
  bnam := Basename(info.ArchiveURL);
  # if the package provides archives named 'version.format',
  # we rename them to 'packagename-version.format'
  if bnam[1] in "0123456789" then
      bnam:=Concatenation( info.PackageName, "-", bnam );
  fi;  
  arch := Concatenation(webdir, "/ftpdir/tar.gz/packages/", bnam,".tar.gz");
  dname := StringSystem("sh", "-c", Concatenation("tar tzf ", arch,
           "| head -2| tail -1"));
  if '/' in dname then
    dname := dname{[1..Position(dname, '/')-1]};
  fi;
  Append(res, "<h4>Online documentation</h4>\n");
  info.HTMLManLinks := "";
  for a in books do
    Append(res, "<p>");
    Append(res, a.BookName );
    Append(res, ": ");
    manlink := "<tr><td>";
    if IsBound(a.HTMLStart) then
      Append(res, Concatenation(" [<a href='{{GAPManualLink}}/pkg/", 
              dname,  "/", a.HTMLStart, 
              "'> HTML</a>] version&nbsp;&nbsp;" ));
      Append(manlink, Concatenation("<a href=\"{{GAPManualLink}}/pkg/", 
        dname, "/", a.HTMLStart, "\">", a.BookName, "</a></td>"));
    else
      Append(manlink, Concatenation(a.BookName, "</td>"));
    fi;
    if IsBound(a.PDFFile) then
      Append(res, Concatenation(" [<a href='{{GAPManualLink}}/pkg/", 
              dname, "/", a.PDFFile, 
              "'> PDF</a>] version&nbsp;&nbsp;" ));
      Append(manlink, Concatenation("<td>[<a href=\"{{GAPManualLink}}/pkg/",
        dname, "/", a.PDFFile, 
        "\">PDF</a>]&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>"));
    else
      Append(manlink, "<td>&nbsp;</td>");
    fi;
    Append(res,"\n</p>\n");
    # link entry for manuals overview
    if IsBound(a.LongTitle) then 
      Append(manlink, Concatenation("<td>", a.LongTitle, "</td></tr>\n"));
    else
      Append(manlink, "<td>&nbsp;</td></tr>\n");
    fi;
    Append(info.HTMLManLinks, manlink);
  od;
  
  # links to archives
  Append(res, "<h4>Download</h4>\n<p>");
  # README and then archives
  if not IsBound(info.ArchiveURL) then
    info.ArchiveURL := "n.a.";
  fi;
  arch := Concatenation(nam, "/", bnam);
  Append(res, Concatenation("[<a href='{{GAPManualLink}}/pkg/", 
          dname, "/README.", nam, 
          "'>README</a>]&nbsp;&nbsp;&nbsp;&nbsp;",bnam));
  for ext in [ ".tar.gz", ".tar.bz2", "-win.zip", ".zip" ] do
    fn := Concatenation(webdir, "/ftpdir/", ext{[2..Length(ext)]}, 
          "/packages/", bnam, ext);
    s := StringSizeFilename(fn);
    Append(res, Concatenation("[<a href='{{gap4www}}", ext{[2..Length(ext)]}, 
           "/packages/", bnam, ext, "'>", ext, 
           "&nbsp; (", s, ")</a>]&nbsp;&nbsp;\n"));
  od;
  Append(res, "\n");
  Append(res, "</p>\n\n");

  if IsBound(info.SourceRepository) then
    Append(res, "<h4>Source code repository</h4>\n<p>");
    Append(res, Concatenation( info.SourceRepository.Type, " : " ) );
    if Length(info.SourceRepository.URL) > 4 and info.SourceRepository.URL{[1..4]}="http" then
      Append(res, Concatenation( "<a href=\"", info.SourceRepository.URL, "\">",
                                               info.SourceRepository.URL, "</a></p>\n"));
    else
      Append(res, Concatenation( info.SourceRepository, "</p>\n"));
    fi;
  fi;

  if IsBound(info.IssueTrackerURL) then
    Append(res, "<h4>Issue tracker</h4>\n<p>");
    Append(res, Concatenation( "<a href=\"", info.IssueTrackerURL, "\">",
                                             info.IssueTrackerURL, "</a></p>\n"));
  fi;

  if IsBound(info.SupportEmail) then
    Append(res, "<h4>Support email address</h4>\n<p>");
    Append(res, Concatenation( "<a href=\"mailto:", info.SupportEmail, "\">",
                                                    info.SupportEmail, "</a></p>\n"));
  fi;

  # full given contact information
  Append(res, "<h4>Contact</h4>\n<p>\n");
  if not IsBound(info.Persons) then
    info.Persons := [];
  fi;
#Jump
  for a in info.Persons do
    if IsBound(a.IsMaintainer) and a.IsMaintainer = true then

        Append(res, Concatenation(a.FirstNames, " ", a.LastName, "<br />\n"));
        if IsBound(a.PostalAddress) then
            Append(res, "Address:<br />\n");
            Append(res, SubstitutionSublist(a.PostalAddress,"\n", "<br />\n"));
            Append(res, "<br />\n");
        fi;
        if IsBound(a.WWWHome) then
            Append(res, "WWW: <a href=\"");
            Append(res, Concatenation(a.WWWHome, "\">", a.WWWHome, "</a><br />\n"));
        fi;
        if IsBound(a.Email) then
        Append(res, "E-mail: <a href=\"mailto:");
        Append(res, Concatenation(a.Email, "\">", a.Email, "</a><br />\n"));
        fi;
        Append(res,"</p><p>\n");
    fi;
  od;
  Append(res, "</p>\n");
  Append(res,"\n</mixer>\n");

  info.HTMLInfoMixer := res;
  return res;
end;

EnsureUTF8Strings := function(r)
  local uni, res, a, i;
  if LoadPackage("GAPDoc", "1.0") <> true then
    Error("Please install GAPDoc version >= 1.0 ...\n");
  fi;
  if IsString(r) then
    # heuristic: assume that encoding is UTF-8 if string is valid UTF-8
    # otherwise assume latin1 and convert
    uni := Unicode(r, "UTF-8");
    if uni <> fail then 
      return r;
    else
      res:="";
      for a in r do
       i:=IntChar(a);
       if i < 128 then
         Add(res, a);
       else
         Add(res, CharInt(192 + Int(i/64)));
         Add(res, CharInt(128 + (i mod 64)));
       fi;
     od;
     return res;
    fi;
  elif IsRecord(r) then
    res := rec();
    for a in RecFields(r) do
      res.(a) := EnsureUTF8Strings(r.(a));
    od;
    return res;
  elif IsList(r) then
    res := [];
    for i in [1..Length(r)] do
      if IsBound(r[i]) then
        res[i] := EnsureUTF8Strings(r[i]);
      fi;
    od;
    return res;
  else
    return r;
  fi;
end;

# This function
# writes variable setting for package web pages in a python readable file
# <pkgconffile>.
# It also creates the short info pages for each package, like ace.mixer, ...
# these files are written in <webdir>/Packages.
# It also produces Mixer code to be edited and pasted into the Mixer page 
# containing the description of the particular archive.
# The current archive files must be in <webdir>/ftpdir/<fmt>   with <fmt> in
# tar.gz, tar.bz2, win.zip and zip.
WritePackageWebPageInfos := function(webdir, pkgconffile, pkgstaticfile)
  local mergedarchivelinks, templ, treelines, pi, fl, fn, manualslinks, 
    suggestupgradeslines, nam, lnam, pkgmix, mixfile, linkentry, staticentry,
    ss, s, tree, mantempl, names, str, lines, strs, updtempl, a, pers, l, 
    webftp, n, esc, uc;
  Print("Updating info for web pages ...\n");
  # empty result file
  pkgconffile := OutputTextFile(pkgconffile, false);
  pkgstaticfile := OutputTextFile(pkgstaticfile, false);
  SetPrintFormattingStatus(pkgconffile, false);
  SetPrintFormattingStatus(pkgstaticfile, false);
  PrintTo(pkgconffile, "# -*- coding: utf-8 -*-\n");
  PrintTo(pkgstaticfile, "<table class=\"par\">\n");
  # a function to escape "'''" in python readable strings
  esc := function(s)
    local pos, off, res;
    pos := PositionSublist(s, "'''");
    if pos = fail then
      return s;
    fi;
    off := 0;
    res := "";
    while pos <> fail do
      Append(res, s{[off+1..pos-1]});
      Append(res, "'''\"'''\"'''");
      off := pos+2;
      pos := PositionSublist(s, "'''", off);
    od;
    Append(res, s{[off+1..Length(s)]});
    return res;
  end;
  treelines := [];
  pi := PACKAGE_INFOS;

  Print("Enumerating packages ...\n");
  # write the <pkgname>.mixer files and fill the package.mixer entries and
  # the 'tree' file and manual overview lines and SuggestUpgrade args
  manualslinks := rec();
  suggestupgradeslines := rec();
  pi := EnsureUTF8Strings(pi);
  for a in SortedList( NamesOfComponents(pi) ) do
    Print( a, "\n" );
    nam := pi.(a).PackageName;
    lnam := LowercaseString(pi.(a).PackageName);
    pkgmix := AddHTMLPackageInfo(pi.(a), webdir);
    mixfile := "";
    # line for 'tree' file
    #Append(mixfile, "");
    Add(treelines, [lnam, 
                    Concatenation("  <entry file=\"", lnam, ".html\">",
                    nam, "</entry>\n")]);
    # write <pkgname>.mixer file
    Append(mixfile, Concatenation("/", lnam));
    FileString(Concatenation(webdir, "/Packages/", mixfile, ".mixer"), pkgmix);
    linkentry := Concatenation("<a href=\"{{pkgmixerpath}}", 
                 mixfile, ".html\">",
                 nam, "</a>&nbsp;&nbsp;", 
                 pi.(a).Version, " (", pi.(a).Date, ") by ");
    staticentry  := Concatenation("<tr><td><a href=\"{{pkgmixerpath}}", 
                 mixfile, ".html\">", nam, "</a>&nbsp;</td><td>", 
                 pi.(a).Version, "&nbsp;</td><td>&nbsp;", 
                 pi.(a).Date, "&nbsp;&nbsp;</td><td>" );                 
    if IsBound(pi.(a).Subtitle) then
      Append(staticentry, Concatenation( pi.(a).Subtitle, "</td></tr>" ) );
    else  
      Append(staticentry, "</td></tr>" );
    fi;                 
    # list entry in overview
    ss := [];
    if not IsBound(pi.(a).Persons) then
      pi.(a).Persons := [];
    fi;
    for pers in pi.(a).Persons do
      s := List(SplitString(pers.FirstNames, "", " "), x-> 
                Concatenation(InitialSubstringUTF8String(x,1), ". "));
      Add(ss, Concatenation(Concatenation(s), pers.LastName)); 
    od;
    Append(linkentry, JoinStringsWithSeparator(ss, ", "));
    if IsBound(pi.(a).Subtitle) then
      Append(linkentry, Concatenation("\n<br />", pi.(a).Subtitle, "\n"));
    fi;
    Append(linkentry, "\n");
    AppendTo(pkgconffile, "PKG_OverviewLink_", esc(lnam), " = r'''",
             esc(linkentry), "'''\n\n");
    AppendTo(pkgstaticfile, esc(staticentry), "\n\n");
    manualslinks.(lnam) := pi.(a).HTMLManLinks;
    suggestupgradeslines.(lnam) := pi.(a).SuggestUpgradesEntry;
  od;
  AppendTo(pkgstaticfile, "</table>\n");
  
  Print("Updating the package tree ...\n");
  # for tree file, all packages sorted alphabetically by name
  tree := "";
  Sort(treelines);
  for a in treelines do
    Append(tree, a[2]);
  od;

  Print("Preparing the manuals overview ...\n");
  # now the manuals overview
  names := ShallowCopy(NamesOfComponents(manualslinks));
  Sort(names);
  str := JoinStringsWithSeparator(List(names, a-> manualslinks.(a)), "\n");
  for n in names do
    AppendTo(pkgconffile, "PKG_ManualLink_", n, " = r'''", 
             esc(manualslinks.(n)), "'''\n\n");
  od;
  AppendTo(pkgconffile, "PKG_AllManualLinks = r'''", esc(str), "'''\n\n");
  
  # info for SuggestUpgrades
  Print("Preparing information for SuggestUpgrades ...\n");
  names := ShallowCopy(NamesOfComponents(suggestupgradeslines));
  Sort(names);
  lines := [ "[ \"GAPKernel\", \"<mixer var='GAPKernelVersion'/>\" ], ",
             "[ \"GAPLibrary\", \"<mixer var='GAPLibraryVersion'/>\" ], " ];
  # now sort by package name and format for lines < 65 characters
  for a in names do
    Add(lines, suggestupgradeslines.(a));
  od;
  strs := [];
  str := "        ";
  for l in lines do;
    if Length(str) + Length(l) < 65 then
      Append(str, l);
    else
      Add(strs, str);
      str := Concatenation("        ", l);
    fi;
  od;
  Add(strs, str);
  str := JoinStringsWithSeparator(strs, "\n");
  AppendTo(pkgconffile, "PKG_SuggestUpgradeLines = r'''", esc(str), 
           "\n'''\n\n");
end;


# some general utilities using the above functions
UpdateAllPackages := function(pkgdir)
  # NOT USED SINCE GAP 4.5, not guaranteed to work
  local addpackagelines, newinfo, newarch, fun, inmerge, newdoc, pkgdocdir;
  # first save the current setup with a time stamp
  addpackagelines := AddpackageLinesCurrent(pkgdir);
  FileString(Concatenation("addpackageCurrent_", StringCurrentTime()), 
             addpackagelines);
  # now start the update
  newinfo := UpdatePackageInfoFiles(pkgdir);
  newarch := UpdatePackageArchives(pkgdir, Concatenation(pkgdir,
             "/../web"));
  fun := function(nam, stat)
    READPackageInfo(Concatenation(pkgdir, "/", nam, "/PackageInfo.g"));
    return PACKAGE_INFOS.(nam).Status = stat;
  end;
  if true then #ForAny(newarch, a-> fun(a, "accepted") or fun(a, "deposited")) then
    inmerge := true;
  else 
    inmerge := false;
  fi;
  if inmerge then
    MergePackages(pkgdir, Concatenation(pkgdir, "/../tmp/tmpmerge"), 
                       inmerge);
  fi;
  pkgdocdir := Concatenation(pkgdir, "/../web/Packages/pkg");
  Exec(Concatenation("mkdir -p ", pkgdocdir));
  newdoc := UpdatePackageDoc(pkgdir, pkgdocdir);
  if Length(newinfo) > 0 or Length(newarch) > 0 then
    ReadAllPackageInfos(pkgdir);
    WritePackageWebPageInfos(Concatenation(pkgdir, "/../web"),
      Concatenation(pkgdir, "/../web/Packages/pkgconf.py"));
  fi;
  Print("\n\n==============   SUMMARY ========\n\nChanged info files: ", 
    " ", newinfo, "\n\nNew archive files in: ",
    newarch, "\n\nNewly merged packages: ", inmerge,
    "\n\nNew documentation: ", newdoc, "\n\n");
end;


###########################################################################
#
# This functions adds new packages for the redistribution, checks that the 
# stored URLs of PackageInfo.g files coincide with the given ones, and 
# migrates packages to new PackageInfo.g URLs, when the "MOVE" option is 
# used. Its arguments are:
# pkgdir - environment variable PkgCacheDir
# pkgreposdir - environment variable PkgReposDir
# urlsfile - name of the file with PackageInfo.g URLs
#
AddPackages := function(pkgdir, pkgreposdir, urlsfile )
local input, line, pkgname, pkginfourl, inmove, nam, info;
input:=InputTextFile( urlsfile);

while true do

  inmove:=false;
  line := ReadLine(input);
  if line = fail then
    return;
  fi;  
  line:=NormalizedWhitespace(line);
  if Length(line) = 0 or line[1]='#' then
    continue;
  fi;  

  line:=SplitString( line, " " );
  if Length(line) = 2 then
    pkgname := line[1];
    pkginfourl := line[2];
    if pkginfourl{[1..4]} <> "http" then
      Print("Error: misformatted line - the URL should start with http\n", line, "\n");
      continue;
    fi;
  elif Length(line) = 3 then
    pkgname := line[1];
    pkginfourl := line[3];
    if pkginfourl{[1..4]} <> "http" then
      Print("Error: misformatted line - the URL should start with http\n", line, "\n");
      continue;
    fi;  
    if line[2]="MOVE" then   
      inmove:=true;
    else  
      Print("Error: misformatted line\n", line, "\n");
      continue;
    fi;
  else
    Print("Error: misformatted line\n", line, "\n");
    continue;
  fi;    
  
  nam := LowercaseString(NormalizedWhitespace(pkgname));
  
  # create the repository to store package releases, if it does not exist
  
  if not IsExistingFile( Concatenation( pkgreposdir, "/", nam ) ) then
    Exec( Concatenation( "mkdir -p ", pkgreposdir, "/", nam) );
    Exec( Concatenation( "cd ", pkgreposdir, "/", nam, " ; ",
                         "hg init") );
    Print("Package ", pkgname, " added for redistribution\n");      
  fi;
  
  if IsExistingFile( Concatenation( pkgdir, "/", nam, "/PackageInfo.g" ) ) then
    ClearPACKAGE_INFOS();
    READPackageInfo( Concatenation( pkgdir, "/", nam, "/PackageInfo.g" ) );
    info := PACKAGE_INFOS.(nam);
    if info.PackageInfoURL = pkginfourl then
      # stored URL coincides with the given in the argument - do nothing
      continue;
    else
      # stored URL differs from the argument - print warning
      Print("*** Package ", pkgname, " - different PackageInfo.g URL:\n",
            "  Our   : ", pkginfourl, "\n",
            "  Stored: ", info.PackageInfoURL, "\n" );
      if not inmove then      
        continue;
      fi;  
    fi; 
  fi;
  
  # if a new package is added, or package is moved to a new URL, create 
  # a template for PackageInfo.g with only three components: .PackageName, 
  # .PackageInfoURL and .Status
  Exec(Concatenation("mkdir -p ", pkgdir, "/", nam));
  PrintTo( Concatenation(pkgdir, "/", nam, "/PackageInfo.g"), 
           Concatenation("SetPackageInfo( rec( \n PackageName := \"", nam,  
                         "\",\nPackageInfoURL := \"", pkginfourl, "\",\n",
                         "Status := \"unknown\"  ) );\n"));
  Print("Set URL of PackageInfo.g for package ", pkgname, " to\n       ", 
        pkginfourl, "\n");    
od;
end;

