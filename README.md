iOS Unity3D 游戏修改实战
==============


最近玩了一个叫 旅行青蛙 的手机游戏，主人公大佬是一只可爱的蛤，最爱的就是去西方各个国家旅行，旅行过程中会寄送明信片回来。玩家要通过收取三叶草来买道具给蛤用，越好的道具越可能得到稀有明信片。三叶草每隔一段时间会重新长出。

本文从加速游戏时间和修改三叶草数值 这两方面来进行说明，提供两种修改方法。

###1. 准备工作

在越狱设备上手动脱壳一份IPA安装包； THEOS开发环境；Hopper。 在此不再赘述。

###2. 加速游戏时间

加速游戏时间可通过Hook系统时间函数，将返回的时间往后累计修改。经测试，Hook gettimeofday 有效，设计实现如下。启动时加载上次记录的时间点`gStartTimestamp`，然后在gettimeofday里，将返回的结果以此时间点往后累计，这样在正常游戏的时候并不改变帧率，如果需要改变，则将此时间间隔`addSeconds`调快。另外，在 `applicationDidEnterBackground`中，每次切入后台后将 `gStartTimestamp` 往后调 2小时，则下次切回游戏时，会使用该新时间，三叶草一般可以收割了，如果想加快蛤回家，多切几次后台回来即可。


###2. 修改三叶草数量

使用Hopper分析64位可执行程序发现，里面做了符号剔除，除了一个广告SDK外，并没有太多有价值的信息。被剔除符号表后，函数大部分是以sub_XXXX的形式的C函数。不要着急，查看二进制文件中的字符串信息，发现是以Unity3D引擎编写的程序，应该是使用 IL2CP 选项来编译的C代码。

[关于IL2CPP的介绍](https://docs.unity3d.com/Manual/IL2CPP.html)

直接分析可执行文件难度较大，不过，以此方式编译的代码，游戏逻辑使用的字符串都保存在 `Data/Managed/Metadata/global-metadata.dat` 中，将IPA包解压开，找到该文件，这时候，搬出我们的大杀器 [Il2CppDumper](https://github.com/Perfare/Il2CppDumper)， 找个win机器，运行 Il2CppDumper， 先选择二进制可执行程序，然后选择 global-metadata.dat，平台选择 64bit, 模式选择Auto，运行结束，会生成dump.cs和script.py两个文件和一个DummyDll文件夹，这里，先打开生成的 `dump.cs`，这样，里面是游戏所有C#头文件信息。

先大概浏览一下，我们的目标是修改三叶草的数量， 秉着大胆假设小心求证的理念，在里面搜索关键词 `Frog` 即青蛙，发现有如下定义：


	public class ObjectMaster_MainOut : ObjectMaster // TypeDefIndex: 2392
	{
		// Fields
		public GameObject CloverFarm; // 0x20
		public GameObject Post; // 0x28
		public GameObject Table; // 0x30
		public GameObject Door; // 0x38
		public GameObject Frog; // 0x40
		public GameObject frontBackMain; // 0x48


可以判定，三叶草在代码里的命名为 `Clover`，以此为关键词继续搜索，发现 `类SuperGameMaster` 的 

	public static void getCloverPoint(int num); // 0x1000938BC
	public static int CloverPointStock(); // 0x100093A2C 

比较可疑，从字面意思和函数参数返回值看 CloverPointStock 应该是获取库存的三叶草数量，getCloverPoint 应该是更新设置三叶草数量(这里难道不该命名为 setCloverPoint ？？？)。 Il2CppDumper dump出来的头文件后面跟的二进制数字注释，就是该函数在IDA/Hopper中的位置。 

到这里，直接打开Hopper，跳转到 CloverPointStock 的位置 `0x100093A2C`，直接修改汇编代码，将该函数的返回值修改掉，
arm64里面 int 类型的函数返回值存在 w0 寄存器，这里直接修改w0寄存器的值然后让函数返回。 
选择菜单 `Modify - Assembel Instruction`, 先输入 `mov w0, #0xffff`, 然后点击弹窗的 `Assemble and Go Next`, 再输入 `ret`
 
[截图](https://github.com/neil-wu/iOSUnityGameMod_frog/Hopper.jpg)


然后先保存文件，再选择菜单 `File - Produce New Executable`, 生成新的可执行文件。


###3. 打包新IPA

在第二步中，我们是在越狱环境下进行的测试，Tweak会生成一个 dylib动态库，想要在非越狱环境下运行，需要重新打包新的IPA并签名。 

假定 xxxx.dylib是越狱环境下的Tweak动态库文件，先使用 install_name_tool 修改一下库依赖， 

`install_name_tool -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @executable_path/libsubstrate.dylib xxxx.dylib`

libsubstrate.dylib 为非越狱环境下使用的substrate库。 将 xxxx.dylib libsubstrate.dylib 和 第三步生成的新文件覆盖到原包中，并将 xxxx.dylib 注入到可执行程序中 `yololib tabikaeru testfrog.dylib`

打包为IPA-签名-安装。










