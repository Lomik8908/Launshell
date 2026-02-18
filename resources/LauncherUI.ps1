##MainUI.ps1
$main_ui = @{
    #Main Window
    window = [System.Windows.Forms.Form]@{
        ClientSize = "320, 240"
        Text = "Launshell"
        FormBorderStyle = "FixedDialog"
        MaximizeBox = $false
        StartPosition = "CenterScreen"
        Icon = $resources.main_icon
    }

    tabs = [System.Windows.Forms.TabControl]@{Size = "322, 220"}

    ## Status Strip
    status = [System.Windows.Forms.StatusStrip]@{
	    SizingGrip = $false
	    ShowItemToolTips = $true
    }
    refresh = [System.Windows.Forms.ToolStripButton]@{
	    ToolTipText = [string]$lang.refreshvers
	    Image = $resources.refresh_status
    }
    folder = [System.Windows.Forms.ToolStripButton]@{
	    ToolTipText = [string]$lang.openfolder
	    Image = $resources.folder_status
    }
    profile = [System.Windows.Forms.ToolStripButton]@{
	    ToolTipText = [string]$lang.profiles
	    Image = $resources.profiles_status
    }
    statustext = [System.Windows.Forms.ToolStripStatusLabel]@{}
    folder_choose = [System.Windows.Forms.ContextMenuStrip]@{ShowImageMargin = $false}


    # Main Tabs
    play_tab = [System.Windows.Forms.TabPage]@{Text = [string]$lang.playtab}
    settings_tab = [System.Windows.Forms.TabPage]@{Text = [string]$lang.settingtab}
    users_tab = [System.Windows.Forms.TabPage]@{Text = [string]$lang.usertab}
    credits_tab = [System.Windows.Forms.TabPage]@{Text = [string]$lang.credtab}


    # Play Tab
    user_label = [System.Windows.Forms.Label]@{
        Location = "25, 25"
        Size = "264, 15"
        Text = [string]$lang.user
    }
    user_box = [System.Windows.Forms.TextBox]@{
        Location = "25, 40"
        Size = "264, 15"
        ReadOnly = $true
    }
    version_label = [System.Windows.Forms.Label]@{
        Location = "25, 70"
        Size = "264, 15"
        Text = [string]$lang.version
    }
    version_box = [System.Windows.Forms.ComboBox]@{
        Location = "25, 85"
        Size = "264, 20"
        DropDownStyle = "DropDownList"
    }
    play_btn = [System.Windows.Forms.Button]@{
        Location = "25, 129"
        Size = "264, 40"
        Text = [string]$lang.play
    }


    # Settings
    settings_tabs = [System.Windows.Forms.TabControl]@{Size = "316, 194"}
    setgame_tab = [System.Windows.Forms.TabPage]@{Text = [string]$lang.gametab}
    setlaunch_tab = [System.Windows.Forms.TabPage]@{Text = [string]$lang.launchertab}
    settheming_tab = [System.Windows.Forms.TabPage]@{Text = [string]$lang.customization}
    setdownload_tab = [System.Windows.Forms.TabPage]@{Text = [string]$lang.downloading}
    ## Game Tab

    #gamedirectory
    dir_label = [System.Windows.Forms.Label]@{
        Location = "5, 35"
        Size = "298, 15"
        Text = [string]$lang.gamedir
    }
    dir_box = [System.Windows.Forms.TextBox]@{
        Location = "5, 50"
        Size = "154, 20"
		ReadOnly = $true
    }
    dir_def = [System.Windows.Forms.Button]@{
        Location = "162, 49"
        Size = "70, 22"
        Text = [string]$lang.reset
    }
    dir_btn = [System.Windows.Forms.Button]@{
        Location = "234, 49"
        Size = "70, 22"
        Text = [string]$lang.change
    }

    #resolution
    res_label = [System.Windows.Forms.Label]@{
        Location = "5, 75"
        Size = "298, 15"
        Text = [string]$lang.resolution
    }
    resx_box = [System.Windows.Forms.NumericUpDown]@{
        Location = "5, 90"
        Size = "60, 20"
        Minimum = 0
        Maximum = 65535
    }
    resy_box = [System.Windows.Forms.NumericUpDown]@{
        Location = "83, 90"
        Size = "60, 20"
        Minimum = 0
        Maximum = 65535
    }
    x_label = [System.Windows.Forms.Label]@{
        Location = "63, 90"
        Size = "20, 20"
        TextAlign = "MiddleCenter"
        Text = "X"
    }
    fullscreen_box = [System.Windows.Forms.CheckBox]@{
        Location = "153, 90"
        Size = "150, 20"
        Text = [string]$lang.fullscreen
    }

    #memory
    mem_label = [System.Windows.Forms.Label]@{
        Location = "5, 115"
        Size = "298, 15"
        Text = [string]$lang.memory
    }
    mem_slide = [System.Windows.Forms.TrackBar]@{
        Location = "5, 130"
        Size = "210, 20"
        LargeChange = 512
        SmallChange = 256
        Minimum = 1024
        Maximum = 1048576
        TickFrequency = 512
    }
    mem_box = [System.Windows.Forms.NumericUpDown]@{
        Location = "220, 130"
        Size = "60, 20"
        Minimum = 0
        Maximum = 1048576
        Increment = 128
    }
    mb_label = [System.Windows.Forms.Label]@{
        Location = "275, 130"
        Size = "28, 20"
        Text = [string]$lang.mb
        TextAlign = "MiddleCenter"
    }

    #other
    other_btn = [System.Windows.Forms.Button]@{
        Location = "5, 5"
        Size = "298, 24"
        Text = [string]$lang.other
    }

    ## Launcher Tab

    #onlaunch
    launch_label = [System.Windows.Forms.Label]@{
        Location = "5, 5"
        Size = "298, 15"
        Text = [string]$lang.whenlaunch
    }
    launch_box = [System.Windows.Forms.ComboBox]@{
        Location = "5, 20"
        Size = "298, 20"
        DropDownStyle = "DropDownList"
    }

    #lang
    lang_label = [System.Windows.Forms.Label]@{
        Location = "5, 45"
        Size = "298, 15"
        Text = [string]$lang.language
    }
    lang_box = [System.Windows.Forms.ComboBox]@{
        Location = "5, 60"
        Size = "298, 20"
        DropDownStyle = "DropDownList"
    }

    #checks
    console_box = [System.Windows.Forms.CheckBox]@{
        Location = "5, 85"
        Size = "144, 20"
        Text = [string]$lang.showconsole
    }

    ##Theming
    showver_box = [System.Windows.Forms.CheckBox]@{
        Location = "5, 5"
        Size = "298, 20"
        Text = [string]$lang.profile_dp
    }

    ##Downloading
    checkass_box = [System.Windows.Forms.CheckBox]@{
        Location = "159, 5"
        Size = "144, 20"
        Text = [string]$lang.checkasset
    }
    checkhash_box = [System.Windows.Forms.CheckBox]@{
        Location = "5, 5"
        Size = "144, 20"
        Text = [string]$lang.checkhash
    }
    redownlib_box = [System.Windows.Forms.CheckBox]@{
        Location = "159, 25"
        Size = "144, 20"
        Text = [string]$lang.relib
    }
    redownass_box = [System.Windows.Forms.CheckBox]@{
        Location = "5, 25"
        Size = "144, 20"
        Text = [string]$lang.reasset
    }
    redownjav_box = [System.Windows.Forms.CheckBox]@{
        Location = "5, 45"
        Size = "144, 20"
        Text = [string]$lang.rejava
    }

    # Users
    users_list = [System.Windows.Forms.ListBox]@{
        Location = "10, 10"
        Size = "294, 134"
    }
    adduser_btn = [System.Windows.Forms.Button]@{
        Location = "9, 155"
        Size = "90, 30"
        Text = [string]$lang.add
    }
    changeuser_btn = [System.Windows.Forms.Button]@{
        Location = "215, 155"
        Size = "90, 30"
        Text = [string]$lang.change
        Enabled = $false
    }

    # Credits
    credits_label = [System.Windows.Forms.Label]@{
        Location = "10, 10"
        Size = "294, 174"
        Text = [string]$lang.credits
    }
    fox = [System.Windows.Forms.PictureBox]@{
        Image = $resources.fox
        SizeMode = "Zoom"
        Size = "100, 60"
        Location = "230, 130"
    }
    refresh_user = [System.Windows.Forms.Button]@{
        Location = "5, 150"
        Size = "24, 24"
        Image = $resources.person
    }
    launchver = [System.Windows.Forms.Label]@{
        Location = "5, 174"
        Size = "100, 15"
        Text = "Launshell $launchver"
    }
}
$main_ui.open_rootf = $main_ui.folder_choose.Items.Add([string]$lang.openrootfolder)
$main_ui.open_versf = $main_ui.folder_choose.Items.Add([string]$lang.openverfolder)

# Add Objects
$main_ui.window.Controls.AddRange(@($main_ui.status, $main_ui.tabs))
$main_ui.tabs.Controls.AddRange(@($main_ui.play_tab, $main_ui.settings_tab, $main_ui.users_tab, $main_ui.credits_tab))
$main_ui.play_tab.Controls.AddRange(@($main_ui.user_label, $main_ui.user_box, $main_ui.version_label, $main_ui.version_box, $main_ui.play_btn))
$main_ui.settings_tab.Controls.Add($main_ui.settings_tabs)
$main_ui.users_tab.Controls.AddRange(@($main_ui.users_list, $main_ui.adduser_btn, $main_ui.changeuser_btn))
$main_ui.credits_tab.Controls.AddRange(@($main_ui.fox, $main_ui.launchver, $main_ui.refresh_user, $main_ui.credits_label))
$main_ui.settings_tabs.Controls.AddRange(@($main_ui.setgame_tab, $main_ui.setlaunch_tab, $main_ui.settheming_tab, $main_ui.setdownload_tab))
$main_ui.setgame_tab.Controls.AddRange(@($main_ui.other_btn, $main_ui.dir_label, $main_ui.dir_box, $main_ui.dir_def, $main_ui.dir_btn, $main_ui.res_label, $main_ui.resx_box, $main_ui.resy_box, $main_ui.x_label, $main_ui.fullscreen_box, $main_ui.mem_label, $main_ui.mem_slide, $main_ui.mem_box, $main_ui.mb_label))
$main_ui.settheming_tab.Controls.Add($main_ui.showver_box)
$main_ui.setdownload_tab.Controls.AddRange(@($main_ui.redownlib_box, $main_ui.redownass_box, $main_ui.redownjav_box, $main_ui.checkass_box, $main_ui.checkhash_box))
$main_ui.setlaunch_tab.Controls.AddRange(@($main_ui.launch_label, $main_ui.launch_box, $main_ui.lang_label, $main_ui.lang_box, $main_ui.console_box))


$main_ui.launch_box.Items.AddRange(@([string]$lang.hidelaunch, [string]$lang.closelaunch, [string]$lang.donone))
$main_ui.status.Items.AddRange(@($main_ui.refresh, $main_ui.folder, $main_ui.profile, $main_ui.statustext))

##VersionUI.ps1
$version_ui = @{
    #Main Window
    window = [System.Windows.Forms.Form]@{
        ClientSize = "250, 230"
        Text = [string]$lang.profiles
        FormBorderStyle = "FixedDialog"
        MaximizeBox = $false
        MinimizeBox = $false
        StartPosition = "CenterScreen"
        Icon = $resources.main_icon
    }
    list_box = [System.Windows.Forms.ListBox]@{
        Location = "10, 10"
        Size = "230, 173"
    }
    refresh_btn = [System.Windows.Forms.Button]@{
        Location = "210, 190"
        Size = "30, 30"
        Image = $resources.refresh
    }
	refresh_tip = [System.Windows.Forms.ToolTip]@{}
    add_btn = [System.Windows.Forms.Button]@{
        Location = "10, 190"
        Size = "30, 30"
        Image = $resources.add
    }
	add_tip = [System.Windows.Forms.ToolTip]@{}
    edit_btn = [System.Windows.Forms.Button]@{
        Location = "40, 190"
        Size = "30, 30"
        Image = $resources.edit
		Enabled = $false
    }
	edit_tip = [System.Windows.Forms.ToolTip]@{}
    delete_btn = [System.Windows.Forms.Button]@{
        Location = "70, 190"
        Size = "30, 30"
        Image = $resources.delete
		Enabled = $false
    }
	delete_tip = [System.Windows.Forms.ToolTip]@{}
    <#more_btn = [System.Windows.Forms.Button]@{
        Location = "100, 190"
        Size = "30, 30"
        Image = $resources.more
		Enabled = $false
    }#>
    #more_list = [System.Windows.Forms.ContextMenuStrip]@{ShowImageMargin = $false}
	#more_tip = [System.Windows.Forms.ToolTip]@{}
}
<#$version_ui.convertminecraft = $version_ui.more_list.Items.Add("Convert profiles from .minecraft")
$version_ui.convertfile = $version_ui.more_list.Items.Add("Convert profiles from file")
$version_ui.convertgamedir = $version_ui.more_list.Items.Add("Convert profiles from GameDir")
#>
$version_ui.refresh_tip.SetToolTip($version_ui.refresh_btn, [string]$lang.refreshvers)
$version_ui.add_tip.SetToolTip($version_ui.add_btn, [string]$lang.addver)
$version_ui.delete_tip.SetToolTip($version_ui.delete_btn, [string]$lang.deletever)
$version_ui.edit_tip.SetToolTip($version_ui.edit_btn, [string]$lang.editver)
#$version_ui.more_tip.SetToolTip($version_ui.more_btn, [string]$lang.morever)
$version_ui.window.Controls.AddRange(@($version_ui.list_box, $version_ui.refresh_btn, $version_ui.add_btn, $version_ui.delete_btn, $version_ui.edit_btn, $version_ui.more_btn))

#$version_ui.more_btn.Add_Click({$version_ui.more_list.Show($version_ui.more_btn, "0,0")})

##OtherUI.ps1
$other_ui = @{
    #Main Window
    window = [System.Windows.Forms.Form]@{
        ClientSize = "300, 135"
        Text = [string]$lang.othersett
        FormBorderStyle = "FixedDialog"
        MaximizeBox = $false
        MinimizeBox = $false
        StartPosition = "CenterScreen"
        Icon = $resources.main_icon
    }
    opti_label = [System.Windows.Forms.Label]@{
        Location = "10, 10"
        Size = "280, 15"
        Text = [string]$lang.optiarg
    }
    opti_box = [System.Windows.Forms.ComboBox]@{
        Location = "10, 25"
        Size = "130, 22"
        DropDownStyle = "DropDownList"
    }
    auth_box = [System.Windows.Forms.CheckBox]@{
        Location = "150, 25"
        Size = "140, 22"
        Text = [string]$lang.reauthpoint
    }
    mcarg_label = [System.Windows.Forms.Label]@{
        Location = "10, 50"
        Size = "280, 15"
        Text = [string]$lang.mcargs
    }
    mcarg_box = [System.Windows.Forms.TextBox]@{
        Location = "10, 65"
        Size = "280, 22"
    }
    jvarg_label = [System.Windows.Forms.Label]@{
        Location = "10, 90"
        Size = "280, 15"
        Text = [string]$lang.jvargs
    }
    jvarg_box = [System.Windows.Forms.TextBox]@{
        Location = "10, 105"
        Size = "280, 22"
    }
}
$other_ui.window.Controls.AddRange(@($other_ui.opti_box, $other_ui.opti_label, $other_ui.auth_box, $other_ui.mcarg_box, $other_ui.mcarg_label, $other_ui.jvarg_box, $other_ui.jvarg_label))
[void]$other_ui.opti_box.Items.Add([string]$lang.none)

##VersionDialog.ps1
$version_dialog = @{
    #Main Window
    edit = $false
    window = [System.Windows.Forms.Form]@{
        ClientSize = "300, 122"
        Text = [string]$lang.addver
        FormBorderStyle = "FixedDialog"
        MaximizeBox = $false
        MinimizeBox = $false
        StartPosition = "CenterScreen"
        Icon = $resources.main_icon
    }
    #Main
    #Name
    name_label = [System.Windows.Forms.Label]@{
        Location = "10, 10"
        Size = "280, 15"
        Text = [string]$lang.name
    }
    name = [System.Windows.Forms.TextBox]@{
        Location = "10, 25"
        Size = "280, 22"
        Text = [string]$lang.untitled
    }
    #Version
    ver_label = [System.Windows.Forms.Label]@{
        Location = "10, 50"
        Size = "280, 15"
        Text = [string]$lang.version
    }
    ver = [System.Windows.Forms.ComboBox]@{
        Location = "10, 65"
        Size = "250, 22"
        DropDownStyle = "DropDownList"
    }
    ver_fil = [System.Windows.Forms.Button]@{
        Location = "270, 65"
        Size = "21, 21"
        Image = $resources.filter
    }
    #Expanded
    #Dir
    dir_label = [System.Windows.Forms.Label]@{
        Location = "10, 120"
        Size = "280, 15"
        Text = [string]$lang.gamedir
    }
    dir = [System.Windows.Forms.TextBox]@{
        Location = "10, 135"
        Size = "150, 20"
        ReadOnly = $true
    }
    dir_btn = [System.Windows.Forms.Button]@{
        Location = "230, 134"
        Size = "60, 22"
        Text = [string]$lang.change
    }
    dirdef_btn = [System.Windows.Forms.Button]@{
        Location = "165, 134"
        Size = "60, 22"
        Text = [string]$lang.reset
    }
    #Ram
    mem_label = [System.Windows.Forms.Label]@{
        Location = "10, 160"
        Size = "140, 15"
        Text = [string]$lang.memory
    }
    mem = [System.Windows.Forms.NumericUpDown]@{
        Location = "10, 175"
        Size = "60, 20"
        Increment = 128
        Maximum = 1048576
    }
    mb = [System.Windows.Forms.Label]@{
        Location = "70, 175"
        Size = "26, 22"
        Text = [string]$lang.mb
        TextAlign = "MiddleCenter"
    }
    #Optimized Arguments
    opti_label = [System.Windows.Forms.Label]@{
        Location = "150, 160"
        Size = "140, 15"
        Text = [string]$lang.optiarg
    }
    opti_box = [System.Windows.Forms.ComboBox]@{
        Location = "150, 175"
        Size = "140, 23"
        DropDownStyle = "DropDownList"
    }
    #Java Arguments
    arg_label = [System.Windows.Forms.Label]@{
        Location = "10, 200"
        Size = "280, 15"
        Text = [string]$lang.jvargs
    }
    arg = [System.Windows.Forms.TextBox]@{
        Location = "10, 215"
        Size = "280, 22"
    }
    #Minecraft Arguments
    mcarg_label = [System.Windows.Forms.Label]@{
        Location = "10, 240"
        Size = "280, 15"
        Text = [string]$lang.mcargs
    }
    mcarg = [System.Windows.Forms.TextBox]@{
        Location = "10, 255"
        Size = "280, 22"
    }
    #Other
    ver_fils = [System.Windows.Forms.ContextMenuStrip]@{}
    expanded = $false
    more_btn = [System.Windows.Forms.Button]@{
        Location = "9, 90"
        Size = "70, 22"
        Text = [string]$lang.more
    }
    info = [System.Windows.Forms.label]@{
        Location = "90, 90"
        Size = "120, 20"
        TextAlign = "MiddleCenter"
    }
    save_btn = [System.Windows.Forms.Button]@{
        Location = "221, 90"
        Size = "70, 22"
        Text = [string]$lang.save
    }
}
$version_dialog.inst = $version_dialog.ver_fils.Items.Add([string]$lang.onlyinstalled)
$version_dialog.ver_alph = $version_dialog.ver_fils.Items.Add([string]$lang.s_alpha)
$version_dialog.ver_beta = $version_dialog.ver_fils.Items.Add([string]$lang.s_beta)
$version_dialog.ver_snap = $version_dialog.ver_fils.Items.Add([string]$lang.s_snapshot)
$version_dialog.ver_adv = $version_dialog.ver_fils.Items.Add([string]$lang.s_advanced)

$version_dialog.inst.CheckOnClick = $true
$version_dialog.ver_alph.CheckOnClick = $true
$version_dialog.ver_beta.CheckOnClick = $true
$version_dialog.ver_snap.CheckOnClick = $true
$version_dialog.ver_adv.CheckOnClick = $true

$version_dialog.window.Controls.AddRange(@($version_dialog.name, $version_dialog.name_label, $version_dialog.ver_fil, $version_dialog.ver, $version_dialog.ver_label, $version_dialog.dir, $version_dialog.dir_btn, $version_dialog.dirdef_btn, $version_dialog.dir_label, $version_dialog.mem, $version_dialog.mb, $version_dialog.opti_box, $version_dialog.opti_label, $version_dialog.mem_label, $version_dialog.arg, $version_dialog.arg_label, $version_dialog.mcarg, $version_dialog.mcarg_label, $version_dialog.more_btn, $version_dialog.info, $version_dialog.save_btn))
$version_dialog.opti_box.Items.AddRange(@([string]$lang.none, [string]$lang.default))

$version_dialog.more_btn.Add_Click({
    if ($version_dialog.expanded) {
        $version_dialog.expanded = $false
        $version_dialog.window.ClientSize = "300, 122"
    } else {
        $version_dialog.expanded = $true
        $version_dialog.window.ClientSize = "300, 285"
    }
})
$version_dialog.ver_fil.Add_Click({$version_dialog.ver_fils.Show($version_dialog.ver_fil, "0,0")})

##UserDialog.ps1
$user_ui = @{
    #Main Window
    window = [System.Windows.Forms.Form]@{
        ClientSize = "300, 70"
        Text = [string]$lang.adduser
        FormBorderStyle = "FixedDialog"
        MaximizeBox = $false
        MinimizeBox = $false
        StartPosition = "CenterScreen"
        Icon = $resources.main_icon
    }
    username = [System.Windows.Forms.TextBox]@{
        Location = "10, 10"
        Size = "250, 20"
    }
    randomize = [System.Windows.Forms.Button]@{
        Location = "268, 9"
        Size = "22, 22"
        Image = $resources.random
    }
    info = [System.Windows.Forms.Label]@{
        Location = "10, 40"
        Size = "125, 20"
        TextAlign = "MiddleLeft"
    }
    save_btn = [System.Windows.Forms.Button]@{
        Location = "145, 38"
        Size = "70, 22"
        Text = [string]$lang.save
    }
    remove_btn = [System.Windows.Forms.Button]@{
        Location = "220, 38"
        Size = "70, 22"
        Text = [string]$lang.remove
		Enabled = $false
    }
}
$user_ui.window.Controls.AddRange(@($user_ui.username, $user_ui.randomize, $user_ui.info, $user_ui.save_btn, $user_ui.remove_btn))