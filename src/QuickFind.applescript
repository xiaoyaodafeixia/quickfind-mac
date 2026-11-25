-- QuickFind —— macOS 原生文件名搜索（Everything 风格）
-- 双引擎：Spotlight 索引秒出 + 可选深扫隐藏目录
-- 未建索引的外接盘：界面里直接给「建索引」按钮，走系统密码框，不用开终端

property maxRows : 400

on run
	-- 关键：从 Finder 启动时必须显式激活，否则 display dialog 在后台会直接失败、app 秒退
	activate
	try
		my main()
	on error errText number errNum
		display alert "QuickFind 出错" message (errText & return & return & "错误码：" & errNum) as critical
	end try
end run

on joinList(theList, sep)
	set out to ""
	repeat with x in theList
		if out is "" then
			set out to (contents of x)
		else
			set out to out & sep & (contents of x)
		end if
	end repeat
	return out
end joinList

on main()
	-- 搜索核心打包在 app 内部，复制到任何位置都能跑
	set appPath to POSIX path of (path to me)
	if appPath does not end with "/" then set appPath to appPath & "/"
	set corePath to appPath & "Contents/Resources/quickfind-core.sh"
	set homePath to do shell script "printf %s \"$HOME\""

	-- ---------- 外接卷清单 + 各自的 Spotlight 索引状态 ----------
	set volNames to {}
	set noIndexVols to {}
	try
		set rawVolNames to do shell script "ls -1 /Volumes 2>/dev/null | grep -v '^Macintosh HD$' | grep -v '^com\\.apple\\.'"
		if rawVolNames is not "" then
			repeat with vn in (paragraphs of rawVolNames)
				set vName to contents of vn
				if vName is not "" then
					set end of volNames to vName
					set idxState to do shell script "mdutil -s " & quoted form of ("/Volumes/" & vName) & " 2>&1 | tail -1"
					if idxState contains "disabled" then set end of noIndexVols to vName
				end if
			end repeat
		end if
	end try

	set scopeLine to "范围：本机"
	if (count of volNames) > 0 then set scopeLine to "范围：本机 + 外接盘"

	set bodyText to "文件名关键词（支持部分匹配，可直接用 * 通配符）" & return & scopeLine & return & "「深搜」会直扫外接盘和隐藏目录，稍慢"

	-- 有盘没建索引时，多给一个「建索引」按钮（建索引要 root，靠系统密码框授权）
	if (count of noIndexVols) > 0 then
		set bodyText to bodyText & return & "⚠ 未建索引：" & my joinList(noIndexVols, "、") & "（点「建索引」可修，或直接用深搜）"
		set btnList to {"取消", "快搜", "深搜", "建索引"}
	else
		set btnList to {"取消", "快搜", "深搜"}
	end if

	-- ---------- 输入 ----------
	try
		set dlg to display dialog bodyText default answer "" with title "QuickFind" buttons btnList default button "快搜" cancel button "取消" with icon note
	on error number -128
		return
	end try

	set kw to text returned of dlg
	set btn to button returned of dlg

	-- ---------- 建索引 ----------
	if btn is "建索引" then
		set theCmd to ""
		repeat with v in noIndexVols
			set theCmd to theCmd & "mdutil -i on " & quoted form of ("/Volumes/" & (contents of v)) & "; "
		end repeat
		try
			do shell script theCmd with administrator privileges
			display alert "已开始建索引" message "正在为下列磁盘建 Spotlight 索引：" & return & my joinList(noIndexVols, "、") & return & return & "建索引在后台跑，小盘几分钟，大盘可能几十分钟到几小时。建好之前用「深搜」照样能搜到盘里全部文件。" as note
		on error errText number errNum
			if errNum is -128 then return
			display alert "建索引没成功" message errText & return & return & "最常见原因：这块盘是 exFAT 或 NTFS 格式，Spotlight 不支持给它建索引。用「深搜」代替就行。" as warning
		end try
		return
	end if

	if kw is "" then return

	if btn is "深搜" then
		set searchMode to "deep"
	else
		set searchMode to "quick"
	end if

	-- ---------- 搜索 ----------
	set sedExpr to "s|^" & homePath & "|~|"
	set theCmd to quoted form of corePath & " " & quoted form of kw & " " & quoted form of searchMode & " | sed " & quoted form of sedExpr

	with timeout of 300 seconds
		set rawOut to do shell script theCmd
	end timeout

	if rawOut is "" then
		display alert "没找到" message "关键词：" & kw & return & return & "试试「深搜」，它会扫 Spotlight 不管的隐藏目录和外接盘。" as warning
		return
	end if

	set allLines to paragraphs of rawOut
	-- 去掉可能出现的空行
	set shownLines to {}
	repeat with ln in allLines
		if (contents of ln) is not "" then set end of shownLines to (contents of ln)
	end repeat
	set totalN to count of shownLines

	-- ---------- 结果列表 ----------
	set shown to shownLines
	set truncatedNote to ""
	if totalN > maxRows then
		set shown to items 1 thru maxRows of shownLines
		set truncatedNote to "（共 " & totalN & " 条，仅显示前 " & maxRows & " 条，请加更精确的关键词）"
	end if

	set promptText to "共 " & totalN & " 条匹配" & truncatedNote & return & "选中一条后点击「定位」："
	set winTitle to "QuickFind · " & kw

	try
		set chosen to choose from list shown with prompt promptText with title winTitle default items {item 1 of shown} OK button name "定位" cancel button name "关闭"
	on error number -128
		return
	end try

	if chosen is false then return
	set sel to item 1 of chosen

	-- ---------- ~ 还原为绝对路径并定位 ----------
	if sel starts with "~/" then
		set selPath to homePath & (text 2 thru -1 of sel)
	else if sel is "~" then
		set selPath to homePath
	else
		set selPath to sel
	end if

	try
		do shell script "open -R " & quoted form of selPath
	on error
		display alert "打不开" message selPath as warning
	end try
end main
