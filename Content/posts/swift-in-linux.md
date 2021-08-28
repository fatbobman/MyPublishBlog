---
date: 2021-02-15 15:00
description: 本文的目标是在Linux上搭建一个可供生产标准的Swift开发调试环境。使用者将获得一个支持代码高亮、自动补全、定义跳转、断点调试、代码美化、代码静态扫描、跨操作系统平台配置的综合开发体验。
tags: Swift,Linux,swiftformat,swiftlint,vscode
title: 在Linux系统上搭建Swift开发调试环境
---
## Swift与Linux ##

自2015年Swift宣布开源并支持Linux后，一晃已超过5年。在最初几年间尽管Swift发展迅速，但并未被Linux社区广泛接受。造成这种局面的原因较多，其中既有语言稳定性方面的问题，同时又有对Linux的支持不完善、缺乏具有吸引力的基础库和第三方库、热点项目不足等多方面原因。

最近两年，上述问题均得到显著改善。

* 从Swift5开始Swift团队宣布ABI稳定了。自此，Swift为应用程序提供了二进制兼容性，有了ABI稳定性作为基础，Swift对其他平台的支持速度和力度将大大提高
* 2020年Swift团队推出了5.3版本，除了“重要的质量提升和性能增强”之外，Swift5.3的一个关键特性是正式支持Linux和Window平台。事实上，这也是Swift的发布流程首次为三个不同的平台分别设立了发布负责人。作为承诺将Swift引入Linux的第一份成果，Swift团队宣布新的Swift版本可用于一众Linux发行版上。
* 出现了大量优秀的官方和第三方的跨平台库。仅Apple公司，最近几年来已经为Swift社区贡献了大量的Swift代码，并保持着非常高的提交频率。
* Swift在服务器端及深度学习领域取得了不错的应用成果。

Swift已经准备在Linux有更多的表现。

## 写本文的原因 ##

前些日子写了篇[用Publish创建博客（一）——入门](/posts/publish-1/)（一个用Swift编写的优秀的静态网站生成器）的介绍，期间有网友问我是否可以在Linux上使用，我回答不成问题。但转过头来思考，虽然`Publish`完美地支持Linux，但开发者能否像在mac上一样方便的进行开发调试呢？

之前使用`Vapor`的时候，曾通过`Docker`在Ubuntu上安装过Swift，不过代码是在mac上调试的。我也十分好奇，在2021年Swift到底在Linux下的开发环境如何？

本文的目标是在Linux上搭建一个可供生产标准的Swift开发调试环境。使用者将获得一个支持代码高亮、自动补全、定义跳转、断点调试、代码美化、代码静态扫描、跨操作系统平台配置的综合开发体验。

## 准备 ##

由于每个人使用的Linux发行版本不同，因此在安装过程中，如遇到缺少必要依赖的情况，请自行按系统提示安装所需的依赖库即可。

本文在描述每一步该如何做的同时，还会做出必要的解释。即使你使用的是其他的Linux发行版，或者不同的编辑器，甚至在Swift或其他工具发生了重大的升级后，仍可按照下面安装思路进行环境搭建。

本文搭建的起点是建立在已经安装了Visual Studio Code 1.53.0的Ubuntu 20.04LTS（最小化安装）系统上的。选择安装的Swift Toolchain为5.3.3。

对于Ubuntu 20.04,需安装`python2.7`及`npm`以完成下面其他操作。

```bash
$ sudo apt install libpython2.7 libpython2.7-dev libz3-4 npm 
```

## Swift Toolchain ##

### 工具链选择 ###

尽管你可以直接[下载Swift Toolchain的源码](https://github.com/apple/swift/releases)自己编译，但目前最推荐的方式还是使用官方提供的已编译好的下载包进行安装。[swift.org](https://swift.org/download/#releases)上提供了Ubuntu 16.04、Ubuntu 18.04、Ubuntu 20.04、CentOS 7、CentOS 8、Amazon Linux 2的下载包。其他的发行版本也多有自己的官方支持，比如Fodor、Red Hat Enterprise Linux8、Raspbian OSi等

Swift在5.3版本后开始正式支持Linux平台，所以本文选择在Ubuntu 20.04上安装[Swift 5.3.3 Release](https://swift.org/builds/swift-5.3.3-release/ubuntu2004/swift-5.3.3-RELEASE/swift-5.3.3-RELEASE-ubuntu20.04.tar.gz)。

### 安装Toolchain ###

在[swift.org](https://swift.org/download/)上查找对应发行版的Swift Toolchain下载地址

![image-20210214092353715](https://cdn.fatbobman.com/swift_toolchain_download.png)

```bash
$cd ~
$wget https://swift.org/builds/swift-5.3.3-release/ubuntu2004/swift-5.3.3-RELEASE/swift-5.3.3-RELEASE-ubuntu20.04.tar.gz
```

解压文件

```bash
$tar -xzf swift-5.3.3-RELEASE-ubuntu20.04.tar.gz 
```

swift工具链将被解压在 `~/swift-5.3.3-RELEASE-ubuntu20.04`目录中，将该目录移动到你习惯的路径，比如：

```bash
$sudo mv swift-5.3.3-RELEASE-ubuntu20.04 /usr/share/swift
```

请记住移动后的路径`/usr/share/swift`，该路径将在下面的配置中被多次使用到。

将swift bin的路径添加到环境中

```bash
$echo "export PATH=/usr/share/swift/usr/bin:$PATH" >> ~/.bash
$source .bash
```

至此，Swift已经在当前系统上安装好了

```bash
$swift --version
Swift version 5.3.3 (swift-5.3.3-RELEASE)
Target: x86_64-unknown-linux-gnu
```

### 运行第一段代码 ###

创建`hello.swift`，内容为

```swift
#!/usr/bin/env swift
print("My first swift code")
```

```bash
$cd ~
$swift hello.swift
My first swift code
```

或者可以将swift代码当做script来执行

```bash
$chmod +755 hello.swift
$./hellow.swift
My first swift code
```

### 创建第一个Swift项目 ###

Swift Package Manager (SPM) 是苹果推出的用于创建使用swift的库和可执行程序的工具。目前它已经是Swift Toolchain的一部分了。

创建可执行程序项目

```bash
$cd ~
$mdkir MyProject
$cd MyProject
$swift package init --type executable
Creating executable package: MyProject
Creating Package.swift
Creating README.md
Creating .gitignore
Creating Sources/
Creating Sources/MyProject/main.swift
Creating Tests/
Creating Tests/LinuxMain.swift
Creating Tests/MyProjectTests/
Creating Tests/MyProjectTests/MyProjectTests.swift
Creating Tests/MyProjectTests/XCTestManifests.swift
```

编译并运行该项目

```bash
~/MyProject$swift run
[4/4] Linking MyProject
Hello, world!
```

该项目在下面的配置中还将使用到。也可以直接使用vscode打开项目文件

```bash
~/MyProject$code .
```

![image-20210214144908318](https://cdn.fatbobman.com/swift_in_linux_vscode_overview.png)

vscode对于Swift已经内置支持了代码高亮。

## SourceKit-LSP ##

### 什么是LSP ###

`LSP`的全程是`Language Sever Protocol`，是微软提出的一项标准化协议，旨在统一开发工具与`Lanuguage Server`之间的通信。`LSP`为支持的语言提供了一套通用的功能集，包括：语法高亮、自动补全、定义跳转、查找引用等等。苹果公司从2018年开始为Swift社区提供了[LSP的代码](https://github.com/apple/sourcekit-lsp)及支持。目前`LSP`已经被集成到了Swift的工具链中。

### 安装LSP ###

尽管Swift ToolChain中已经集成了`LSP`，但是我们还是需要为`vscode`安装对应的插件并进行配置，才能在vscode中使用Swift的LSP功能。

由于Swift LSP插件没有被放置在`vscode`的插件市场中，我们还是需要从苹果的[LSP Github](https://github.com/apple/sourcekit-lsp)站点上下载

```bash
$git clone https://github.com/apple/sourcekit-lsp.git
```

下载的文件包含全部LSP的代码和插件代码，我们只需安装插件代码。

```bash
$cd sourcekit-lsp/Editors/vscode/
$npm run createDevPackage 
```

> 2021年8月更新

新的LSP版本更改了插件编译命令

```bash
$cd sourcekit-lsp/Editors/vscode/
$npm install
$npm run dev-package
```

![image-20210214151421778](https://cdn.fatbobman.com/swift_in_linux_complie_vscode_lsp.png)

编译成功的插件被放置在 `~/sourcekit-lsp/Editors/vscode/out`目录中。

### 配置vscode ###

通过命令行将插件安装到vscode上

```bash
$cd ~/sourcekit-lsp/Editors/vscode
$code --install-extension sourcekit-lsp-vscode-dev.vsix
```

或者在vscode中选择该插件进行安装

![image-20210214151923560](https://cdn.fatbobman.com/swift_in_linux_vscode_install_lsp.png)

配置`Settings`

![image-20210214154131957](https://cdn.fatbobman.com/swift_in_linux_lsp_setting_1.png)

由于`lsp`已经集成到了swift toolchain中，因此在我们安装toolchain时，它已经被安装到了`/usr/share/swift/usr/bin`的目录中，并且该目录也已经设置在环境的PATH中，因此通常无需指定绝对路径，vscode便可以使用swift的lsp功能。如果你自己单独下载了新版本的lsp，可以在`settings.json`中设置对应的路径。

```json
"sourcekit-lsp.serverPath": "/usr/share/swift/usr/bin/sourcekit-lsp"
```

安装完成后，vscode便可支持代码自动补全、定义跳转等功能。

![swift_in_linux_lsp_demo](https://cdn.fatbobman.com/swift_in_linux_lsp_demo.gif)

## LLDB ##

### 什么是LLDB ###

`LLDB`调试器是`LLVM`项目的调试器组件。它构建为一组可重用的组件，这些组件广泛使用`LLVM`中的现有库，例如`Clang`表达式解析器和`LLVM`反汇编程序。通过`LLDB`，让`vscode`拥有了对Swift代码进行调试的能力。

### 安装LLDB ###

由于Swift Toolchain当前已经集成了`LLDB`，因此我们无需对其进行安装，只需要安装vscode的lldb插件即可。

在vscode的插件市场中，安装`CodeLLDB`

![image-20210214160313240](https://cdn.fatbobman.com/swift_in_linst_install_lldb_in_market.png)

在`settings.json`中指定`lldb`的位置

```json
"lldb.library": "/usr/share/swift/usr/lib/liblldb.so"
```

也可以在`settings UI`中设定

![image-20210214170242254](https://cdn.fatbobman.com/swift_in_linux_setting_lldb_path.png)

### 调试配置文件 ###

在vscode中用lldb对项目进行调试，需要在项目的`.vscode`目录中针对每个项目分别创建调试配置文件`launch.json`和`tasks.json`。

`launch.json`是vscode用于调试的配置文件，比如指定调试语言环境，指定调试类型等等。其作用和`XCode`中的target类似。在swift项目中，我们通常会设置两个`configuration`，一个用于调试程序，一个用于进行`Unit testing`。

```bash
$cd MyProject
$code .
```

在第一次点击左侧的`run`按钮时，vscode会提示创建`launch.json`文件，我们也可以自己手动在`.vscode`目录中创建该文件。

![image-20210214172254927](https://cdn.fatbobman.com/swift_in_linx_create_lanchjson.png)

**launch.json**

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "lldb", 
            "request": "launch",
            "name": "Debug",
            "program": "${workspaceFolder}/.build/debug/MyProject",
            "args": [],
            "cwd": "${workspaceFolder}"，
            "preLaunchTask": "swift-build"
        },
        {
            "type": "lldb",
            "request": "launch",
            "name": "unit testing on Linux",
            "program": "./.build/debug/MyProjectPackageTests.xctest",
            "preLaunchTask": "swift-build-tests"
        }
    ]
}
```

* type

  用于此启动配置的调试器的类型，swift调试需设置成lldb

* request

  此启动配置的请求类型，swift调试需设置成launch，

* name

  在调试启动配置下拉列表中的显示名称

* program

  可执行文件的位置。使用`swift build`编译后（不加realase参数）的执行文件被放置在`项目目录${workspaceFolder}/.build/debug/`下，文件名通常为项目名称（本例为MyProject）；`swift build -c release`编译后的执行文件放置在`${workspaceFolder}/.build/release/`下，文件名为项目名称（本例为MyProject）;`unit testing`的可执行文件放置在`${workspaceFolder}/.build/debug/`，文件名通常为`项目名称PackageTests.xctest`（本例为MyProjectPackageTests.xctest）。请根据每个项目的名称、配置设定该项。

* args

  传递给程序的参数。比如你的项目支持启动参数设定`MyProject name hello`，则`args`为`["name","hello"]`

* cwd

  当前工作目录，用于查找依赖关系和其他文件

* preLaunchTask

  要在调试会话开始之前启动的任务，每个任务都需要在`tasks.json`中有对应的设定。比如本例中，`swift-build`对应着tasks.json中的`label:swift-build`的task。对于swift项目，在调试前最常作的工作便是编译。

**tasks.json**

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "swift-build",
            "type": "shell",
            "command":"swift build"
        },
        {
            "label": "swift-build-tests",
            "type": "process",
            "command": "swift",
            "args": [
                "build",
                "--build-tests"
            ]
        }
    ]
}
```

* lable

  同`launch.json`中的`preLaunchTask`对应

* type

  `shell`或`process`，为了更好的演示，本例中两种形式都采用了。

* command

  如果`type`为`process`，`commnad`只能为需要执行命令的可执行文件名称（不可带参数），在本例中为`swift`,如果`type`为`shell`则可以在`command`中直接写上需要调用的参数，比如`swift build`

* args

  对于`type`为`process`的情况，需要调用的参数在此填写。在本例中，`swift-build-tests`也可以写成 

```json
"label": "swift-build-tests",
"type": "shell",
"command": "swift build --build-tests"
```

`launch.json`和`tasks.json`还有很多其他的选项，更多的用法请参阅[vscode手册](https://code.visualstudio.com/docs/editor/debugging)以及[SPM手册](https://docs.swift.org/package-manager/)。

现在我们就可以开始对Swift项目进行调试了

### 第一次调试 ###

```bash
$cd MyProject
$code .
```

随便给main.swift添加点内容，比如：

```swift
import Foundation
let a = 100
print("Hello, world!\(Int.random(in: 0...100))")
print("a:\(a)")
```

![swift-in-linux-lldb-demo](https://cdn.fatbobman.com/swift-in-linux-lldb-demo.gif)

## SwiftFormat ##

### 为什么要对代码Foramt ###

许多项目都有固定的代码风格，统一的代码规范不仅有助于项目的迭代和维护，同时也让代码更加美观和易读。但并不是每个程序员都能够掌握并熟练使用项目风格约定。通过使用自动化工具完成上述工作是让人十分惬意的事情。

Swift社区中有多个Format项目，目前最活跃的有`nicklockwood`的[swiftformat](https://github.com/nicklockwood/SwiftFormat)和`Apple`的[swift-format](https://github.com/apple/swift-format)。本例中，我们选择安装`nicklockwood`的[swiftformat](https://github.com/nicklockwood/SwiftFormat)。两者的安装方法类似，相对来说`swiftformat`支持的规则更多，另外同Swift 的版本也不像`swift-foramt`那样需要严格绑定。

### 安装命令行工具 ###

```bash
$cd ~
$git clone https://github.com/nicklockwood/SwiftFormat.git
$cd SwiftFormat
$swift build -c release
$sudo cp ~/SwiftFormat/.build/release/swiftformat /usr/local/bin
$swiftformat --version
0.47.11
```

### 安装vscode插件 ###

`swiftformat`、`swift-format`以及`swiftlint`的vscode插件都是由[Valentin Kabel](https://github.com/vknabel)开发的，他同时还管理、开发了其他及个vscode下的swift插件，为在vscode上更好的使用swift作出了不小的贡献。

在插件商店选择swiftformat对应的插件（注意不要选错）。

![image-20210214211153478](https://cdn.fatbobman.com/swift-in-linux-swiftformat-plugin-install.png)

在`settings.json`中添加

```json
"swiftformat.path": "/usr/local/bin/swiftformat",
"swiftformat.configSearchPaths": [
        "./swiftformat",
        "~/.swiftformat"
        ]
```

`swiftformat`将从`Swiftformat.configSearchPaths`设定的路径中尝试查找用户自己创建的配置文件（`.swiftformat`），上面的配置为，如果当前目录没有，则从用户根目录上查找。如果都没有则使用默认配置和规则。

![swift-in-linux-format-demo](https://cdn.fatbobman.com/swift-in-linux-format-demo.gif)

`swiftformat`目前包含50多个规则，它的文档做的很好，可以在[Rules.md](https://github.com/nicklockwood/SwiftFormat/blob/master/Rules.md)中找到最新的规则列表及演示。需要注意的是，vscode目前无法正确的响应`swiftformat`自定义配置中的`--indent`，需要在vscode中对`indent`做单独的设定（我目前采用的是通过`EditorConfig for VS Code`做统一设置）。另外，如果通过`swift.options:["--config","~/rules/.swiftformat"]`指定的规则文件的优先级高于`swiftformat.path`中的规则文件。

## SwiftLint ##

### 让代码更规范 ###

在计算机科学中，lint是一种工具程序的名称，它用来标记源代码中，某些可疑的、不具结构性的段落。它是一种静态程序分析工具，最早适用于C语言，在UNIX平台上开发出来。后来它成为通用术语，可用于描述在任何一种计算机程序语言中，用来标记源代码中有疑义段落的工具。swift社区中，被使用的最广泛的就是`realm`开发的[SwiftLint](https://github.com/realm/SwiftLint)。

其实，上面的swiftformat、swift-format都具有lint的功能，并且和swiftlint在很多地方的规则都类似（都基于[Github's Swift Style Guide](https://github.com/realm/SwiftLint)），但各自的特点还是略有不同。

swiftformat更多的表现在对代码的自动修改上，而swiftlint由于直接hook了Clang和Sourcekit，因此提供了swiftformat所不具备的，代码录入阶段的实时验证和提示功能（通常并不使用它的`autocorrect`）。

### 安装SwiftLint ###

```bash
$git clone https://github.com/realm/SwiftLint.git
$cd SwiftLint
$swift build -c release
$sudo cp ~/SwiftLint/.build/release/swiftlint /usr/local/bin
$swiftlint --version
0.42.0
```

### 安装swiftlint vscode插件 ###

在vscode插件市场中安装swiftlint插件

![image-20210215073043096](https://cdn.fatbobman.com/swift-in-linux-swiftlint-plugin.png)

在`settings.json`中添加

```json
"swiftlint.path": "/usr/local/bin/swiftlint"，
"swiftlint.toolchainPath": "/usr/share/swift/usr/bin",
"swiftlint.configSearchPaths": [
        "./.swiftlint.yml",
        "~/.swiftlint.yml"
    ]
```

`configSearchPath`的设置同`swiftformat`类似，如果不需要自定义配置，则无需填写。

![swift-in-linux-lint-demo](https://cdn.fatbobman.com/swift-in-linux-lint-demo.gif)

## 跨平台配置 ##

我们已经在Ubuntu 20.04上构建了一个较完整的Swift开发环境。

### settings ###

如果你也像我一样使用了vscode的setting同步功能，那么在其他的平台（比如mac），上述的settings.json将无法正常使用。

为了让我们构建的开发环境适应多平台，需要启用配置的多平台支持，并且针对不同平台分别设定。

安装`platform-settins`插件

![image-20210215091440441](https://cdn.fatbobman.com/swift-in-linux-platform-settings.png)

修改`settings.json`

当前为：

```json
{
    "sourcekit-lsp.serverPath": "/usr/share/swift/usr/bin/sourcekit-lsp",
    "lldb.library": "/usr/share/swift/usr/lib/liblldb.so",
    "swiftformat.path": "/usr/local/bin/swiftformat",
    "swiftformat.configSearchPaths": [
        "./swiftformat",
        "~/.swiftformat"
    ],
    "swiftlint.path": "/usr/local/bin/swiftlint",
    "swiftlint.toolchainPath": "/usr/share/swift/usr/bin",
    "swiftlint.configSearchPaths": [
        "./.swiftlint.yml",
        "~/.swiftlint.yml"
    ]
}
```

修改为：

```json
{
    "platformSettings.autoLoad": true,
    "platformSettings.platforms": {
        "linux":{
            "sourcekit-lsp.serverPath": "/usr/share/swift/usr/bin/sourcekit-lsp",
            "lldb.library": "/usr/share/swift/usr/lib/liblldb.so",
            "swiftformat.path": "/usr/local/bin/swiftformat",
            "swiftlint.path": "/usr/local/bin/swiftlint",
            "swiftlint.toolchainPath": "/usr/share/swift/usr/bin",
        },
        "mac":{
            "sourcekit-lsp.serverPath": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp",
            "lldb.library": "/Applications/Xcode.app/Contents/SharedFrameworks/LLDB.framework/Versions/A/LLDB",
            "swiftformat.path": "/usr/local/bin/swiftformat", //homebrew目前也恰巧安装在此
            "swiftlint.path": "/usr/local/bin/swiftlint", //指向工具的实际路径
            "swiftlint.toolchainPath": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin",
        }
    
    },
    "swiftformat.configSearchPaths": [
        "./swiftformat",
        "~/.swiftformat"
    ],
    "swiftlint.configSearchPaths": [
        "./.swiftlint.yml",
        "~/.swiftlint.yml"
    ]
}
```

### launch.json ###

在mac平台下，`unit testing`的调用方式也和linux下不同，因此需要在`launch.json`中添加一个`configuration`，由于使用同一个`preLauchchTask`，因此`tasks.json`不用改动。

```json
       {
            "type": "lldb",
            "request": "launch",
            "name": "Debug tests on macOS",
            "program": "/Applications/Xcode.app/Contents/Developer/usr/bin/xctest", //For example /Applications/Xcode.app/Contents/Developer/usr/bin/xctest
            "args": [
                "${workspaceFolder}/.build/debug/MyProjectPackageTests.xctest"
            ],
            "preLaunchTask": "swift-build-tests"
        },
```

![image-20210215092656451](https://cdn.fatbobman.com/swift-in-linux-launch-multiform.png)

在不同的平台上，选择对应的target即可。

## 结语 ##

希望本文能够帮助更多的朋友在Linux上使用Swift进行开发。
