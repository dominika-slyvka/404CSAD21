--------------------------------------------------------------------------------
-- Модуль      : spi_master_tx
-- Призначення : Передавач SPI Master, режим 3 (CPOL = 1, CPHA = 1).
--               Керує лініями SS_n, SCK і MOSI та передає 8 біт старшим
--               бітом вперед (MSB first).
--                 CPOL = 1 - у стані спокою SCK = '1';
--                 CPHA = 1 - дані виставляються по ведучому фронту (спад SCK, 1 -> 0)
--                            і фіксуються по задньому фронту (фронт SCK, 0 -> 1).
--               Для приймача формується строб sample у момент фронту SCK.
--
-- Автомат станів (FSM):
--   IDLE --start--> SETUP --1/2 T--> TRANSFER --16 перемикань SCK--> HOLD --1/2 T--> IDLE
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master_tx is
    port (
        clk       : in  std_logic;                     -- системний такт
        rst       : in  std_logic;                     -- синхронне скидання
        half_tick : in  std_logic;                     -- строб від spi_clk_gen
        start     : in  std_logic;                     -- запит на обмін (1 такт)
        tx_data   : in  std_logic_vector(7 downto 0);  -- байт для передачі
        sck       : out std_logic;                     -- тактова лінія SPI
        mosi      : out std_logic;                     -- дані Master -> Slave
        ss_n      : out std_logic;                     -- вибір Slave, активний '0'
        sample    : out std_logic;                     -- імпульс 1 такт: фронт SCK
        busy      : out std_logic;                     -- '1' поки йде обмін
        done      : out std_logic                      -- імпульс 1 такт: обмін завершено
    );
end entity spi_master_tx;

architecture rtl of spi_master_tx is
    type state_t is (S_IDLE, S_SETUP, S_TRANSFER, S_HOLD);
    signal state : state_t := S_IDLE;

    signal shreg    : std_logic_vector(7 downto 0) := (others => '0'); -- зсувний регістр
    signal edge_cnt : natural range 0 to 15 := 0;   -- номер перемикання SCK (0..15)
    signal sck_r    : std_logic := '1';             -- регістр лінії SCK (CPOL = 1)
    signal mosi_r   : std_logic := '0';             -- регістр лінії MOSI
    signal ss_r     : std_logic := '1';             -- регістр лінії SS_n
begin

    sck  <= sck_r;
    mosi <= mosi_r;
    ss_n <= ss_r;
    busy <= '0' when state = S_IDLE else '1';

    fsm : process (clk)
    begin
        if rising_edge(clk) then
            sample <= '0';
            done   <= '0';

            if rst = '1' then
                state    <= S_IDLE;
                sck_r    <= '1';
                mosi_r   <= '0';
                ss_r     <= '1';
                edge_cnt <= 0;
            else
                case state is

                    -- Шина неактивна: SS_n = 1, SCK = CPOL = 1
                    when S_IDLE =>
                        ss_r  <= '1';
                        sck_r <= '1';
                        if start = '1' then
                            shreg <= tx_data;       -- CPHA = 1: біт вийде на першому спаді
                            ss_r  <= '0';           -- вибір Slave
                            state <= S_SETUP;
                        end if;

                    -- Пів періоду SCK між спадом SS_n і першим фронтом
                    when S_SETUP =>
                        if half_tick = '1' then
                            edge_cnt <= 0;
                            state    <= S_TRANSFER;
                        end if;

                    -- 8 періодів SCK: спад - виставлення біта, фронт - вибірка
                    when S_TRANSFER =>
                        if half_tick = '1' then
                            sck_r <= not sck_r;
                            if sck_r = '1' then
                                mosi_r <= shreg(7);                -- спад SCK (ведучий)
                                shreg  <= shreg(6 downto 0) & '0';
                            else
                                sample <= '1';                     -- фронт SCK (задній)
                            end if;
                            if edge_cnt = 15 then
                                state <= S_HOLD;
                            else
                                edge_cnt <= edge_cnt + 1;
                            end if;
                        end if;

                    -- Пів періоду після останнього фронту (SCK = 1), потім SS_n -> 1
                    when S_HOLD =>
                        if half_tick = '1' then
                            ss_r   <= '1';
                            mosi_r <= '0';
                            done   <= '1';
                            state  <= S_IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process fsm;

end architecture rtl;
