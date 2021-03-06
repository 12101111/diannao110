;这段引导代码会被BIOS加载到SS:SP=0000:7C00地址处，然后运行。  
00000000  33C0              xor ax,ax   ;ax寄存器清0 
00000002  8ED0              mov ss,ax   ;ss=0  
00000004  BC007C            mov sp,0x7c00   ;装填栈指针——SS:SP=0000:7C00  

                            ;设置参数
00000007  8EC0              mov es,ax   ;es=0
00000009  8ED8              mov ds,ax   ;ds=0
0000000B  BE007C            mov si,0x7c00   
0000000E  BF0006            mov di,0x600
00000011  B90002            mov cx,0x200
                            ;将后面的代码都复制到低端内存
                            ;因为PBR的引导程序也会加载到0000:7C00，MBR要腾出地方

                            ;movsb为传送字节，从DS：SI到ES：DI
                            ;rep movsb为重复操作传输动作，直到CX为0
                            ;DF，方向标志，为0规定其后的串操作为正向串操作
                            ;DF=0，每传送一个字节（或movsw的一个字），SI，DI都加1（或加2）
                            ;DF=1，就会减1
                            
                            ;所以以下命令使0x7c00后的0x200个字节移到0x0600
                            ;MBR正好0x200个字节
                            ;所以整个MBR都被移了过去
00000014  FC                cld     ;DF=0
00000015  F3A4              rep movsb

00000017  50                push ax     ;0入栈
00000018  681C06            push word 0x61c     ;0x61c入栈
0000001B  CB                retf    ;弹出两个字到IP和CS,ip=0,cs=0x61c,0x61c:0000即为下一行
0000001C  FB                sti     ;启用中断 IF=1
0000001D  B90400            mov cx,0x4      ;分区表中有4个分区表项
00000020  BDBE07            mov bp,0x7be    ;内存中分区表开始的位置，0x0600+0x01BE
                            
                            ;loop start

00000023  807E0000          cmp byte [bp+0x0],0x0   ;活动分区位与0比

                            ;jl,当cmp为小于时跳转

00000027  7C0B              jl 0x34                 ;小于0就跳转0x34，0x80是有符号数-128
00000029  0F850E01          jnz near 0x13b          ;非0跳转0x13b，输出分区表损坏
0000002D  83C510            add bp,byte +0x10       ;为0，bp+16，读取下一个分区表项目
00000030  E2F1              loop 0x23               ;循环回去

00000032  CD18              int 0x18    ;没有活动分区会执行到这里

                            /*
                            * 没有发现活动分区，无法启动OS，按照规范调用Int 18h
                            * 早期的BIOS的Int 18h中断服务程序就是启动ROM-Basic，
                            * With early computers, the ROM BASIC was a ROM interpreter that allowed users to run and create BASIC programs. 
                            * 现在的BIOS一般是打印错误信息（No Rom Basic,System Halted）
                            */
;0x13 扩展功能用来读取磁盘，可以读取大于128G的空间
00000034  885600            mov [bp+0x0],dl         ;网上说是dl是0x80，即活动分区标志，不知道什么情况
00000037  55                push bp                 ;保存bp，但好像bp并没有变化？？
00000038  C6461105          mov byte [bp+0x11],0x5
0000003C  C6461000          mov byte [bp+0x10],0x0  ;这个位在内存中无用，要么时别的分区信息，要么是MBR的校验位0x55AA
                                                    ;所以被用来记录是否支持int 0x13扩展

00000040  B441              mov ah,0x41
00000042  BBAA55            mov bx,0x55aa
00000045  CD13              int 0x13
00000047  5D                pop bp
00000048  720F              jc 0x59
0000004A  81FB55AA          cmp bx,0xaa55
0000004E  7509              jnz 0x59
00000050  F7C10100          test cx,0x1
00000054  7403              jz 0x59
00000056  FE4610            inc byte [bp+0x10]
00000059  6660              pushad
0000005B  807E1000          cmp byte [bp+0x10],0x0
0000005F  7426              jz 0x87
00000061  666800000000      push dword 0x0
00000067  66FF7608          push dword [bp+0x8]
0000006B  680000            push word 0x0
0000006E  68007C            push word 0x7c00
00000071  680100            push word 0x1
00000074  681000            push word 0x10
00000077  B442              mov ah,0x42
00000079  8A5600            mov dl,[bp+0x0]
0000007C  8BF4              mov si,sp
0000007E  CD13              int 0x13
00000080  9F                lahf
00000081  83C410            add sp,byte +0x10
00000084  9E                sahf
00000085  EB14              jmp short 0x9b
00000087  B80102            mov ax,0x201
0000008A  BB007C            mov bx,0x7c00
0000008D  8A5600            mov dl,[bp+0x0]
00000090  8A7601            mov dh,[bp+0x1]
00000093  8A4E02            mov cl,[bp+0x2]
00000096  8A6E03            mov ch,[bp+0x3]
00000099  CD13              int 0x13
0000009B  6661              popad
0000009D  731C              jnc 0xbb
0000009F  FE4E11            dec byte [bp+0x11]
000000A2  750C              jnz 0xb0
000000A4  807E0080          cmp byte [bp+0x0],0x80
000000A8  0F848A00          jz near 0x136
000000AC  B280              mov dl,0x80
000000AE  EB84              jmp short 0x34
000000B0  55                push bp
000000B1  32E4              xor ah,ah
000000B3  8A5600            mov dl,[bp+0x0]
000000B6  CD13              int 0x13
000000B8  5D                pop bp
000000B9  EB9E              jmp short 0x59
000000BB  813EFE7D55AA      cmp word [0x7dfe],0xaa55
000000C1  756E              jnz 0x131
000000C3  FF7600            push word [bp+0x0]
000000C6  E88D00            call 0x156
000000C9  7517              jnz 0xe2
000000CB  FA                cli
000000CC  B0D1              mov al,0xd1
000000CE  E664              out 0x64,al
000000D0  E88300            call 0x156
000000D3  B0DF              mov al,0xdf
000000D5  E660              out 0x60,al
000000D7  E87C00            call 0x156
000000DA  B0FF              mov al,0xff
000000DC  E664              out 0x64,al
000000DE  E87500            call 0x156
000000E1  FB                sti
000000E2  B800BB            mov ax,0xbb00
000000E5  CD1A              int 0x1a
000000E7  6623C0            and eax,eax
000000EA  753B              jnz 0x127
000000EC  6681FB54435041    cmp ebx,0x41504354
000000F3  7532              jnz 0x127
000000F5  81F90201          cmp cx,0x102
000000F9  722C              jc 0x127
000000FB  666807BB0000      push dword 0xbb07
00000101  666800020000      push dword 0x200
00000107  666808000000      push dword 0x8
0000010D  6653              push ebx
0000010F  6653              push ebx
00000111  6655              push ebp
00000113  666800000000      push dword 0x0
00000119  6668007C0000      push dword 0x7c00
0000011F  6661              popad
00000121  680000            push word 0x0
00000124  07                pop es
00000125  CD1A              int 0x1a
00000127  5A                pop dx
00000128  32F6              xor dh,dh
0000012A  EA007C0000        jmp 0x0:0x7c00
0000012F  CD18              int 0x18
00000131  A0B707            mov al,[0x7b7]
00000134  EB08              jmp short 0x13e
00000136  A0B607            mov al,[0x7b6]
00000139  EB03              jmp short 0x13e
                            ;分区表无效
0000013B  A0B507            mov al,[0x7b5]
0000013E  32E4              xor ah,ah
00000140  050007            add ax,0x700
00000143  8BF0              mov si,ax
00000145  AC                lodsb
00000146  3C00              cmp al,0x0
00000148  7409              jz 0x153
0000014A  BB0700            mov bx,0x7
0000014D  B40E              mov ah,0xe
0000014F  CD10              int 0x10
00000151  EBF2              jmp short 0x145
00000153  F4                hlt
00000154  EBFD              jmp short 0x153
00000156  2BC9              sub cx,cx
00000158  E464              in al,0x64
0000015A  EB00              jmp short 0x15c
0000015C  2402              and al,0x2
0000015E  E0F8              loopne 0x158
00000160  2402              and al,0x2
00000162  C3                ret

Offset        0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F  0123456789ABCDEF

0000000160            49 6E 76 61 6C 69 64 20 70 61 72 74 69    Invalid parti
0000000170   74 69 6F 6E 20 74 61 62 6C 65 00 45 72 72 6F 72  tion table.Error
0000000180   20 6C 6F 61 64 69 6E 67 20 6F 70 65 72 61 74 69   loading operati
0000000190   6E 67 20 73 79 73 74 65 6D 00 4D 69 73 73 69 6E  ng system.Missin
00000001A0   67 20 6F 70 65 72 61 74 69 6E 67 20 73 79 73 74  g operating syst
00000001B0   65 6D 00 00 00 63                                em...c