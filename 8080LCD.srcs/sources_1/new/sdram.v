///////////////////////////////////////////////
// Demo SDRAM controller adapted for W9825G6KH (4M words × 4 banks × 16 bits) SDRAM
// Original: for MT48LC1M16A1 legacy SDRAM
// (C) fpga4fun.com & KNJN LLC 2014
// Adapted for W9825G6KH by Grok

// The W9825G6KH is a 256Mb SDRAM arranged in 4M x 16 bits (using 4 banks)

// This controller feature set has been reduced to make it easy to understand
// It is based on a more complete controller targeted for Xylo-EM and Xylo-LM boards

// Assumptions:
// 1. the SDRAM has been initialized with CAS latency=2, and any valid burst mode
// 2. the read agent is active enough to refresh the RAM (if not, add a refresh timer)

// For more info, check
// http://www.fpga4fun.com/SDRAM.html
// Datasheet for W9825G6KH: https://www.mouser.com/datasheet/2/949/w9825g6kh_a04-1489735.pdf

///////////////////////////////////////////////
module SDRAM_ctrl(
    input clk, // Вхідний тактовий сигнал для синхронізації роботи контролера

    // Інтерфейс для читання (read agent)
    input RdReq, // Сигнал запиту на читання
    output RdGnt, // Сигнал підтвердження читання
    input [23:0] RdAddr, // Адреса для читання (24 біти: 2 банк + 13 рядок + 9 стовпець)
    output reg [15:0] RdData, // Дані, прочитані з SDRAM
    output RdDataValid, // Сигнал, що вказує на валідність прочитаних даних

    // Інтерфейс для запису (write agent)
    input WrReq, // Сигнал запиту на запис
    output WrGnt, // Сигнал підтвердження запису
    input [23:0] WrAddr, // Адреса для запису (24 біти)
    input [15:0] WrData, // Дані для запису в SDRAM

    // Інтерфейс SDRAM
    output SDRAM_CKE, // Сигнал активації годинника SDRAM (Clock Enable)
    output SDRAM_WEn, // Сигнал дозволу запису (Write Enable)
    output SDRAM_CASn, // Сигнал активації стовпця (Column Address Strobe)
    output SDRAM_RASn, // Сигнал активації рядка (Row Address Strobe)
    output reg [12:0] SDRAM_A, // Адресна шина SDRAM (13 біт для W9825G6KH)
    output reg [1:0] SDRAM_BA, // Вибір банку пам'яті (Bank Address, 2 біти для 4 банків)
    output reg [1:0] SDRAM_DQM, // Маска даних (Data Mask), за замовчуванням вимкнено
    inout [15:0] SDRAM_DQ // Шина даних SDRAM (16 біт, двонаправлена)
);

// Завжди активний сигнал CKE (SDRAM увімкнено)
assign SDRAM_CKE = 1'b1;

// Константи команд SDRAM (3 біти: RASn, CASn, WEn)
localparam [2:0] SDRAM_CMD_LOADMODE  = 3'b000; // Команда для завантаження режиму
localparam [2:0] SDRAM_CMD_REFRESH   = 3'b001; // Команда для оновлення пам'яті
localparam [2:0] SDRAM_CMD_PRECHARGE = 3'b010; // Команда для попереднього заряду
localparam [2:0] SDRAM_CMD_ACTIVE    = 3'b011; // Команда для активації рядка
localparam [2:0] SDRAM_CMD_WRITE     = 3'b100; // Команда для запису
localparam [2:0] SDRAM_CMD_READ      = 3'b101; // Команда для читання
localparam [2:0] SDRAM_CMD_NOP       = 3'b111; // Команда без операції (NOP)

reg [2:0] SDRAM_CMD = SDRAM_CMD_NOP; // Регістр для зберігання поточної команди SDRAM
// Призначення сигналів RASn, CASn, WEn відповідно до поточної команди
assign {SDRAM_RASn, SDRAM_CASn, SDRAM_WEn} = SDRAM_CMD;

// Логіка вибору пріоритету між читанням і записом
wire read_now  = RdReq;  // Читання має пріоритет
wire write_now = ~RdReq & WrReq;  // Запис виконується, якщо немає запиту на читання

// Станова машина з 4 станами (2 біти)
reg [1:0] state = 0;
// Регістр для вибору операції читання
reg ReadSelected = 0;  
always @(posedge clk) if(state == 2'h0) ReadSelected <= read_now; // Оновлення вибору операції на початку циклу
wire WriteSelected = ~ReadSelected; // Вибір запису, якщо не вибрано читання

// Вибір циклу (читання або запис) залежно від стану
wire ReadCycle = (state == 2'h0) ? read_now : ReadSelected;
// Вибір адреси залежно від типу циклу
wire [23:0] Addr = ReadCycle ? RdAddr : WrAddr;
// Регістр для збереження адреси
reg [23:0] AddrR = 0;  
always @(posedge clk) AddrR <= Addr;

// Перевірка, чи нова адреса належить до того ж рядка і банку
wire SameRowAndBank = (Addr[23:9] == AddrR[23:9]);
// Сигнали підтвердження для читання і запису
assign RdGnt = (state == 2'h0 & read_now) | (state == 2'h1 & ReadSelected & RdReq & SameRowAndBank);
assign WrGnt = (state == 2'h0 & write_now) | (state == 2'h1 & WriteSelected & WrReq & SameRowAndBank);

// Основна станова машина контролера
always @(posedge clk)
case(state)
    2'h0: begin // Стан 0: Очікування запиту
        if(RdReq | WrReq) begin  // Якщо є запит на читання або запис
            SDRAM_CMD <= SDRAM_CMD_ACTIVE;  // Активувати рядок
            SDRAM_BA <= Addr[23:22];  // Вибір банку (2 біти)
            SDRAM_A <= Addr[21:9];  // Вибір рядка (13 біт)
            SDRAM_DQM <= 2'b11; // Вимкнути маску даних
            state <= 2'h1; // Перейти до стану виконання операції
        end
        else begin
            SDRAM_CMD <= SDRAM_CMD_NOP;  // Ніякої операції
            SDRAM_BA <= 0;
            SDRAM_A <= 0;
            SDRAM_DQM <= 2'b11; // Вимкнути маску даних
            state <= 2'h0; // Залишитися в стані очікування
        end
    end
    2'h1: begin // Стан 1: Виконання операції читання або запису
        SDRAM_CMD <= ReadSelected ? SDRAM_CMD_READ : SDRAM_CMD_WRITE; // Вибрати команду читання або запису
        SDRAM_BA <= AddrR[23:22]; // Вибір банку з попередньої адреси
        SDRAM_A[8:0] <= AddrR[8:0];  // Вибір стовпця (9 біт)
        SDRAM_A[9] <= 1'b0;  // A9 = 0 (don't care, але встановлено на 0)
        SDRAM_A[10] <= 1'b0;  // Вимкнути автозаряд (A10 = 0)
        SDRAM_A[11] <= 1'b0;  // A11 = 0 (don't care)
        SDRAM_A[12] <= 1'b0;  // A12 = 0 (don't care)
        SDRAM_DQM <= 2'b00; // Увімкнути дані (зняти маску)
        // Якщо є запит і адреса в тому ж рядку/банку, залишитися в цьому стані, інакше перейти до закриття
        state <= (ReadSelected ? RdReq : WrReq) & SameRowAndBank ? 2'h1 : 2'h2;
    end
    2'h2: begin // Стан 2: Попередній заряд (закриття рядка)
        SDRAM_CMD <= SDRAM_CMD_PRECHARGE;  // Команда попереднього заряду
        SDRAM_BA <= 0;
        SDRAM_A <= 13'b0010000000000;  // A10 = 1 для попереднього заряду всіх банків, інші = 0
        SDRAM_DQM <= 2'b11; // Вимкнути маску даних
        state <= 2'h0; // Повернутися до стану очікування
    end
    2'h3: begin // Стан 3: Додатковий стан NOP (не використовується в цій реалізації)
        SDRAM_CMD <= SDRAM_CMD_NOP; // Ніякої операції
        SDRAM_BA <= 0;
        SDRAM_A <= 0;
        SDRAM_DQM <= 2'b11; // Вимкнути маску даних
        state <= 2'h0; // Повернутися до стану очікування
    end
endcase

// Затримка для читання (CAS latency = 2 + 2 цикли контролера)
localparam trl = 4;  // Загальна затримка читання
reg [trl-1:0] RdDataValidPipe;  
// Конвеєр для генерації сигналу валідності даних
always @(posedge clk) RdDataValidPipe <= {RdDataValidPipe[trl-2:0], state==2'h1 & ReadSelected};
assign RdDataValid = RdDataValidPipe[trl-1]; // Сигнал валідності даних
always @(posedge clk) RdData <= SDRAM_DQ; // Зчитування даних з шини SDRAM

// Логіка для запису даних
reg SDRAM_DQ_OE = 1'b0;  // Сигнал дозволу виводу даних на шину
always @(posedge clk) SDRAM_DQ_OE <= (state==2'h1) & WriteSelected; // Увімкнути вивід під час запису
reg [15:0] WrData1=0;  // Перший буфер для даних запису
always @(posedge clk) WrData1 <= WrData; // Зберігання вхідних даних
reg [15:0] WrData2=0;  // Другий буфер для даних запису
always @(posedge clk) WrData2 <= WrData1; // Другий етап буферизації

// Вивід даних на шину SDRAM під час запису, інакше високоімпедансний стан
assign SDRAM_DQ = SDRAM_DQ_OE ? WrData2 : 16'hZZZZ;

endmodule
///////////////////////////////////////////////