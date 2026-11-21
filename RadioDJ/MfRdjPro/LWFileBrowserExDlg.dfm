object LWFileBrowserExDlg: TLWFileBrowserExDlg
  Left = 0
  Top = 0
  BorderIcons = []
  BorderStyle = bsDialog
  Caption = 'Select an audio file'
  ClientHeight = 640
  ClientWidth = 940
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = [fsBold]
  FormStyle = fsStayOnTop
  OldCreateOrder = True
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 17
  object Splitter1: TSplitter
    Left = 270
    Top = 111
    Width = 6
    Height = 450
    ExplicitTop = 86
    ExplicitHeight = 475
  end
  object SplitterPreview: TSplitter
    Left = 704
    Top = 111
    Width = 6
    Height = 450
    Align = alRight
    ExplicitTop = 86
    ExplicitHeight = 475
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 940
    Height = 111
    Align = alTop
    BevelOuter = bvNone
    Color = 4865081
    DoubleBuffered = True
    ParentBackground = False
    ParentDoubleBuffered = False
    TabOrder = 0
    object lblLocation: TLabel
      Left = 10
      Top = 7
      Width = 53
      Height = 17
      Caption = 'Location'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblIPv4Address: TLabel
      Left = 716
      Top = 7
      Width = 77
      Height = 17
      Caption = 'IPv4 address'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object cbxLocations: TComboBox
      Left = 4
      Top = 29
      Width = 266
      Height = 25
      BevelInner = bvNone
      BevelKind = bkSoft
      BevelOuter = bvRaised
      Style = csOwnerDrawFixed
      Color = 9216
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ItemHeight = 19
      ParentFont = False
      TabOrder = 0
      OnDrawItem = cbxLocationsDrawItem
      OnSelect = cbxLocationsSelect
    end
    object edtPath: TEdit
      Left = 290
      Top = 28
      Width = 337
      Height = 25
      Hint = 'Find a local map or network station. (like: \\MyServer)'
      BevelInner = bvNone
      BevelKind = bkSoft
      BevelOuter = bvRaised
      BorderStyle = bsNone
      Color = 9216
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 1
      OnKeyDown = edtPathKeyDown
    end
    object edtIPv4Address: TEdit
      Left = 716
      Top = 29
      Width = 214
      Height = 25
      Hint = 
        'IPv4 address of the computer for the selected location. Select t' +
        'he text to copy it.'
      BevelInner = bvNone
      BevelKind = bkSoft
      BevelOuter = bvRaised
      BorderStyle = bsNone
      Color = 9216
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      ParentShowHint = False
      ReadOnly = True
      ShowHint = True
      TabOrder = 2
    end
    object cbxFileFilter: TFilterComboBox
      Left = 1
      Top = 80
      Width = 703
      Height = 25
      BevelInner = bvNone
      BevelKind = bkSoft
      BevelOuter = bvRaised
      Color = 9216
      FileList = flbFiles
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 3
    end
    object btnGo: TMPxpButton
      Left = 633
      Top = 20
      Width = 74
      Height = 39
      Margins.Left = 2
      Margins.Top = 2
      Margins.Right = 2
      Margins.Bottom = 2
      Alignment = taCenter
      AllowAllUp = True
      Caption = 'Find'
      Color = 5914932
      ColorWhenDown = 11363625
      ColorWhenUp = 5914932
      Behavior = bbPushButton
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      GlyphTransparentColor = clFuchsia
      GlyphTransparent = True
      HotTrackColor = clWhite
      HotTrackFont.Charset = DEFAULT_CHARSET
      HotTrackFont.Color = clWindowText
      HotTrackFont.Height = -18
      HotTrackFont.Name = 'Segoe UI'
      HotTrackFont.Style = []
      Layout = blGlyphRight
      LightColor = 12348265
      ParentColor = False
      ParentFont = False
      ShadowColor = clSkyBlue
      Style = bsModern
      Transparent = True
      OnClick = btnGoClick
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 561
    Width = 940
    Height = 79
    Align = alBottom
    BevelOuter = bvNone
    Color = 4865081
    DoubleBuffered = True
    ParentBackground = False
    ParentDoubleBuffered = False
    TabOrder = 1
    object lblSelectedFile: TLabel
      Left = 14
      Top = 15
      Width = 79
      Height = 17
      Caption = 'Selected file:'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clAqua
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblDuration: TLabel
      Left = 14
      Top = 44
      Width = 113
      Height = 17
      Caption = 'Duration: 00:00:00'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clAqua
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object btnOk: TMPxpButton
      Left = 711
      Top = 20
      Width = 107
      Height = 40
      Margins.Left = 2
      Margins.Top = 2
      Margins.Right = 2
      Margins.Bottom = 2
      Alignment = taCenter
      AllowAllUp = True
      Caption = 'Ok'
      Color = 5914932
      ColorWhenDown = 11363625
      ColorWhenUp = 5914932
      Behavior = bbPushButton
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      GlyphTransparentColor = clFuchsia
      GlyphTransparent = True
      HotTrackColor = clWhite
      HotTrackFont.Charset = DEFAULT_CHARSET
      HotTrackFont.Color = clWindowText
      HotTrackFont.Height = -18
      HotTrackFont.Name = 'Segoe UI'
      HotTrackFont.Style = []
      Layout = blGlyphRight
      LightColor = 12348265
      ParentColor = False
      ParentFont = False
      ShadowColor = clSkyBlue
      Style = bsModern
      Transparent = True
      OnClick = btnOkClick
    end
    object btnCancel: TMPxpButton
      Left = 827
      Top = 20
      Width = 107
      Height = 40
      Margins.Left = 2
      Margins.Top = 2
      Margins.Right = 2
      Margins.Bottom = 2
      Alignment = taCenter
      AllowAllUp = True
      Caption = 'Cancel'
      Color = 5914932
      ColorWhenDown = 11363625
      ColorWhenUp = 5914932
      Behavior = bbPushButton
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      GlyphTransparentColor = clFuchsia
      GlyphTransparent = True
      HotTrackColor = clWhite
      HotTrackFont.Charset = DEFAULT_CHARSET
      HotTrackFont.Color = clWindowText
      HotTrackFont.Height = -18
      HotTrackFont.Name = 'Segoe UI'
      HotTrackFont.Style = []
      Layout = blGlyphRight
      LightColor = 12348265
      ParentColor = False
      ParentFont = False
      ShadowColor = clSkyBlue
      Style = bsModern
      Transparent = True
      OnClick = btnCancelClick
    end
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 111
    Width = 270
    Height = 450
    Align = alLeft
    BevelOuter = bvNone
    Color = 4865081
    ParentBackground = False
    TabOrder = 2
    object lbFolders: TListBox
      Left = 0
      Top = 0
      Width = 270
      Height = 450
      Style = lbOwnerDrawFixed
      Align = alClient
      Color = 9216
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ItemHeight = 21
      ParentFont = False
      TabOrder = 0
      OnDblClick = lbFoldersDblClick
      OnDrawItem = lbFoldersDrawItem
    end
  end
  object flbFiles: TFileListBox
    Left = 276
    Top = 111
    Width = 428
    Height = 450
    Align = alClient
    Color = 9216
    ExtendedSelect = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWhite
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = []
    ItemHeight = 17
    ParentFont = False
    ShowGlyphs = True
    TabOrder = 3
    OnChange = flbFilesChange
    OnDblClick = flbFilesDblClick
  end
  object pnlPreview: TPanel
    Left = 710
    Top = 111
    Width = 230
    Height = 450
    Align = alRight
    BevelOuter = bvNone
    Color = 4865081
    ParentBackground = False
    TabOrder = 4
    object lblPreview: TLabel
      Left = 0
      Top = 0
      Width = 230
      Height = 17
      Align = alTop
      Alignment = taCenter
      Caption = 'Preview'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Layout = tlCenter
      ExplicitWidth = 48
    end
    object imgPreview: TImage
      Left = 0
      Top = 17
      Width = 230
      Height = 433
      Align = alClient
      Center = True
      Proportional = True
      Stretch = True
      ExplicitTop = 23
      ExplicitHeight = 429
    end
  end
end
