; RUN: llc -mtriple=x86_64-linux < %s | FileCheck %s
; RUN: opt -passes='require<profile-summary>,function(codegenprepare)' -S -mtriple=x86_64-linux < %s | FileCheck %s --check-prefix OPT


; The exit block containing extractvalue can be duplicated into the BB
; containing call. And later tail call can be generated.

; CHECK-LABEL: test1:
; CHECK:       jne foo # TAILCALL
; CHECK:       jmp bar # TAILCALL

; OPT-LABEL:   test1
; OPT:         if.then.i:
; OPT-NEXT:    tail call { ptr, i64 } @bar
; OPT-NEXT:    extractvalue
; OPT-NEXT:    ret
;
; OPT:         if.end.i:
; OPT-NEXT:    tail call { ptr, i64 } @foo
; OPT-NEXT:    extractvalue
; OPT-NEXT:    ret

define ptr @test1(i64 %size) {
entry:
  %cmp.i.i = icmp ugt i64 %size, 16384
  %add.i.i = add i64 %size, 7
  %div.i.i = lshr i64 %add.i.i, 3
  %phitmp.i.i = trunc i64 %div.i.i to i32
  %cmp1.i = icmp eq i32 %phitmp.i.i, 0
  %cmp.i = or i1 %cmp.i.i, %cmp1.i
  br i1 %cmp.i, label %if.end.i, label %if.then.i
  if.then.i:                                        ; preds = %entry
  %call1.i = tail call { ptr, i64 } @bar(i64 %size)
  br label %exit

if.end.i:                                         ; preds = %entry
  %call2.i = tail call { ptr, i64 } @foo(i64 %size)
  br label %exit

exit:
  %call1.i.sink = phi { ptr, i64 } [ %call1.i, %if.then.i ], [ %call2.i, %if.end.i ]
  %ev = extractvalue { ptr, i64 } %call1.i.sink, 0
  ret ptr %ev
}


; The extractvalue extracts a field with non-zero offset, so the exit block
; can't be duplicated.

; CHECK-LABEL: test2:
; CHECK:       callq foo
; CHECK:       callq bar

; OPT-LABEL:   test2
; OPT:         if.then.i:
; OPT-NEXT:    tail call { ptr, i64 } @bar
; OPT-NEXT:    br label %exit
;
; OPT:         if.end.i:
; OPT-NEXT:    tail call { ptr, i64 } @foo
; OPT-NEXT:    br label %exit
;
; OPT:         exit:
; OPT-NEXT:    phi
; OPT-NEXT:    extractvalue
; OPT-NEXT:    ret

define i64 @test2(i64 %size) {
entry:
  %cmp.i.i = icmp ugt i64 %size, 16384
  %add.i.i = add i64 %size, 7
  %div.i.i = lshr i64 %add.i.i, 3
  %phitmp.i.i = trunc i64 %div.i.i to i32
  %cmp1.i = icmp eq i32 %phitmp.i.i, 0
  %cmp.i = or i1 %cmp.i.i, %cmp1.i
  br i1 %cmp.i, label %if.end.i, label %if.then.i
  if.then.i:                                        ; preds = %entry
  %call1.i = tail call { ptr, i64 } @bar(i64 %size)
  br label %exit

if.end.i:                                         ; preds = %entry
  %call2.i = tail call { ptr, i64 } @foo(i64 %size)
  br label %exit

exit:
  %call1.i.sink = phi { ptr, i64 } [ %call1.i, %if.then.i ], [ %call2.i, %if.end.i ]
  %ev = extractvalue { ptr, i64 } %call1.i.sink, 1
  ret i64 %ev
}


; The extractvalue accesses a nest struct type, the extracted field has zero
; offset, so the exit block can still be duplicated, and tail call generated.

; CHECK-LABEL: test3:
; CHECK:       jne qux # TAILCALL
; CHECK:       jmp baz # TAILCALL

; OPT-LABEL:   test3
; OPT:         if.then.i:
; OPT-NEXT:    tail call { { ptr, i64 }, i64 } @baz
; OPT-NEXT:    extractvalue
; OPT-NEXT:    ret
;
; OPT:         if.end.i:
; OPT-NEXT:    tail call { { ptr, i64 }, i64 } @qux
; OPT-NEXT:    extractvalue
; OPT-NEXT:    ret

define ptr @test3(i64 %size) {
entry:
  %cmp.i.i = icmp ugt i64 %size, 16384
  %add.i.i = add i64 %size, 7
  %div.i.i = lshr i64 %add.i.i, 3
  %phitmp.i.i = trunc i64 %div.i.i to i32
  %cmp1.i = icmp eq i32 %phitmp.i.i, 0
  %cmp.i = or i1 %cmp.i.i, %cmp1.i
  br i1 %cmp.i, label %if.end.i, label %if.then.i

if.then.i:                                        ; preds = %entry
  %call1.i = tail call { {ptr, i64}, i64 } @baz(i64 %size)
  br label %exit

if.end.i:                                         ; preds = %entry
  %call2.i = tail call { {ptr, i64}, i64 } @qux(i64 %size)
  br label %exit

exit:
  %call1.i.sink = phi { {ptr, i64}, i64 } [ %call1.i, %if.then.i ], [ %call2.i, %if.end.i ]
  %ev = extractvalue { {ptr, i64}, i64 } %call1.i.sink, 0, 0
  ret ptr %ev
}


; The extractvalue accesses a nest struct with non-zero offset, so the exit
; block can't be duplicated.

; CHECK-LABEL: test4:
; CHECK:       callq qux
; CHECK:       callq baz

; OPT-LABEL:   test4
; OPT:         if.then.i:
; OPT-NEXT:    tail call { { ptr, i64 }, i64 } @baz
; OPT-NEXT:    br label %exit
;
; OPT:         if.end.i:
; OPT-NEXT:    tail call { { ptr, i64 }, i64 } @qux
; OPT-NEXT:    br label %exit
;
; OPT:         exit:
; OPT-NEXT:    phi
; OPT-NEXT:    extractvalue
; OPT-NEXT:    ret

define i64 @test4(i64 %size) {
entry:
  %cmp.i.i = icmp ugt i64 %size, 16384
  %add.i.i = add i64 %size, 7
  %div.i.i = lshr i64 %add.i.i, 3
  %phitmp.i.i = trunc i64 %div.i.i to i32
  %cmp1.i = icmp eq i32 %phitmp.i.i, 0
  %cmp.i = or i1 %cmp.i.i, %cmp1.i
  br i1 %cmp.i, label %if.end.i, label %if.then.i

if.then.i:                                        ; preds = %entry
  %call1.i = tail call { {ptr, i64}, i64 } @baz(i64 %size)
  br label %exit

if.end.i:                                         ; preds = %entry
  %call2.i = tail call { {ptr, i64}, i64 } @qux(i64 %size)
  br label %exit

exit:
  %call1.i.sink = phi { {ptr, i64}, i64 } [ %call1.i, %if.then.i ], [ %call2.i, %if.end.i ]
  %ev = extractvalue { {ptr, i64}, i64 } %call1.i.sink, 0, 1
  ret i64 %ev
}


declare dso_local { ptr, i64 } @foo(i64)
declare dso_local { ptr, i64 } @bar(i64)
declare dso_local { {ptr, i64}, i64 } @baz(i64)
declare dso_local { {ptr, i64}, i64 } @qux(i64)
