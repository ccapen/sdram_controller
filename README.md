# 中文  
## 智能BANK管理和智能刷新的SDRAM控制器  
基于EG4S20NG88型号的FPGA及其内部的EM638325型号的SDRAM平台开发，并在当前有限的环境下工作良好，当前平台使用时钟125MHz。  
该控制器实现了BANK交错和读写中断机制，主动利用行激活和预充电后产生的等待延迟处理队列后的其他BANK数据，且在一定范围内的同BANK同行数据可自动合并读写。  
控制器在空闲时可自动进行刷新，如总线被数据占用，将在一段时间后触发强制刷新，此时数据读写会被阻塞直到需要的刷新量完成。同时，为了保证智能刷新下总能满足SDRAM刷新时序要求，总刷新量会偏高，参数`REFRESH_SLICE`越小冗余刷新量越多（多`REFRESH_LINE` / `REFRESH_SLICE`次刷新）。  
满足以下条件可提高读写效率：  
1. 上个数据到当前数据为读到读或写到写（实际控制器使用了读写双端口，内部会自动合并，但读写之间切换仍需时间）。  
2. 当上个数据与当前数据行地址不同时，需保证BANK地址也不同（该条件影响最大，可自行重排端口数据以满足要求）。  
3. 芯片设置的突发长度和数据读写突发长度（数据的连贯性）必须大于等于2。  
理想条件下且关闭自动刷新功能，数据率可与时钟频率相同，达到100%（必须是纯读取或纯写入，且数据按特定顺序排列）。在更一般的情况下，数据率会变低。 
   
## 模块参数  
**基础参数：**  
`CLK_FREQ		`  
`ADDRRANK		`  
`ADDRWIDTH		`  
`DATAWIDTH		`  
`BANKNUM			`  
`ROWNUM			`  
`COLNUM			`  
`PHYADDRWIDTH	`  
`PHYBANKWIDTH	`  
`PHYDQMWIDTH		`  
`CASLATENCY		`  
`POWERUP_DELAYMS	`  
`BURSTLENGTH		`  
`BURSTTYPE		`  
  
`ADDRRANK`区分两种地址排列方式，`POWERUP_DELAYMS`决定模块复位信号拉高后延迟多久后启动模块，其他参数按照实际情况填写即可。  
  
**输入缓冲参数：**  
`INWBUFFERDEPTH	`  
`WDATABATCHLENGTH`  
`WMAXBATCHDELAY	`  
`INRBUFFERDEPTH	`  
`RDATABATCHLENGTH`  
`RMAXBATCHDELAY	`  
  
该部分为模块输入部分，由LUT生成的FIFO，不建议设置过大深度，如外部已有FIFO，可直接设置为0。  
`DATABATCHLENGTH`和`MAXBATCHDELAY`用于应对数据率不高但非常连续的读写状况，如0101010101（1代表当前时钟沿有数据读写需求，0代表没有），会将数据迟滞并打包，可能变成0000111101此类。否则该类数据将占用总线，不断重复激活再预充电同一行，使空闲刷新无法发生，并在随后的强制刷新下引入突发的延迟。打包长度必须小于此处FIFO的深度。  
  
**BANK管理和刷新参数：**  
`WPREACTIVEDEPTH	`  
`RPREACTIVEDEPTH	`  
`RWBUFFERDEPTH	`  
`AUTO_REFRESH	`  
`REFRESH_TIME_MS	`  
`REFRESH_LINE	`  
`REFRESH_SLICE	`  
  
`PREACTIVEDEPTH`表示预激活FIFO的深度，该值越大，行激活和预充电产生延迟时能处理的队列后其他数据越多，中间夹杂了其他数据的同BANK同行数据可合并读写的范围越大。不过行激活和预充电产生的延迟有限，超过一定深度后不会有进一步的效果。  
`RWBUFFERDEPTH`为读写合并后的FIFO，可在一定程度上补充`PREACTIVEDEPTH`，在读写两边数据率不均衡时可节省少量FIFO资源。  
`REFRESH_SLICE`表示将一个刷新周期切分为多少个子刷新片，片数越多，冗余刷新次数越少，但会逐渐退化回普通均匀刷新，不能大于`REFRESH_TIME_MS`。  



# EN  
## Sdram controller with intelligent bank manage and referesh  
Developed and work well on EG4S20NG88 and its embedded sdram EM638325, clock frequency is 125MHz.  
It is intelligently to decide the timing of active, read-write and precharge, and intelligently to refresh when the bus is idle or force refresh when the timeline is arrive.  

Read or write datas fllow the rules below can decrease the gaps of read or write:  
1. last data to this data is read-to-read or write-to-write (internal rules, can be ignored);  
2. if row of last data is different to this data, bank of last data must be different to this data;  
3. chip burst length and data burst length must large or equal 2;  
  
In ideal situation and close the auto refresh function, the data rate can be 100%, same to I_clk, no gap(it will be lower in more genral situation).  

## Parameters  
**Basic parameters:**  
`CLK_FREQ		`  
`ADDRRANK		`  
`ADDRWIDTH		`  
`DATAWIDTH		`  
`BANKNUM			`  
`ROWNUM			`  
`COLNUM			`  
`PHYADDRWIDTH	`  
`PHYBANKWIDTH	`  
`PHYDQMWIDTH		`  
`CASLATENCY		`  
`POWERUP_DELAYMS	`  
`BURSTLENGTH		`  
`BURSTTYPE		`  
  
**Input buffer parameters:**  
`INWBUFFERDEPTH	`  
`WDATABATCHLENGTH`  
`WMAXBATCHDELAY	`  
`INRBUFFERDEPTH	`  
`RDATABATCHLENGTH`  
`RMAXBATCHDELAY	`  
  
**Bank manage and refresh parameters:**  
`WPREACTIVEDEPTH	`  
`RPREACTIVEDEPTH	`  
`RWBUFFERDEPTH	`  
`AUTO_REFRESH	`  
`REFRESH_TIME_MS	`  
`REFRESH_LINE	`  
`REFRESH_SLICE	`  
