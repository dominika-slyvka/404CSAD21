--------------------------------------------------------------------------------
-- Модуль      : spi_top
-- Призначення : Верхній рівень SPI Master: дільник частоти, передавач
--               spi_master_tx (SCK, MOSI, SS_n) і приймач spi_master_rx (MISO).
--               Режим SPI 3: CPOL = 1, CPHA = 1.
--               Обмін повнодуплексний: за один кадр передається і
--               приймається по одному байту.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity spi_top is
    generic (
        CLK_FREQ : positive := 25_000_000;
        SCK_FREQ : positive := 500_000
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        -- інтерфейс користувача
        start    : in  std_logic;
        tx_data  : in  std_logic_vector(7 downto 0);
        rx_data  : out std_logic_vector(7 downto 0);
        rx_valid : out std_logic;
        busy     : out std_logic;
        done     : out std_logic;
        -- шина SPI
        sck      : out std_logic;
        mosi     : out std_logic;
        miso     : in  std_logic;
        ss_n     : out std_logic
    );
end entity spi_top;

architecture rtl of spi_top is
    signal half_tick : std_logic;
    signal sample    : std_logic;
    signal ss_int    : std_logic;
begin

    -- Дільник частоти: 25 МГц -> 2 * 500 кГц
    u_clk : entity work.spi_clk_gen
        generic map (CLK_FREQ => CLK_FREQ, SCK_FREQ => SCK_FREQ)
        port map (clk => clk, rst => rst, half_tick => half_tick);

    -- Передавач (Master FSM, SCK/MOSI/SS_n)
    u_tx : entity work.spi_master_tx
        port map (clk => clk, rst => rst, half_tick => half_tick,
                  start => start, tx_data => tx_data,
                  sck => sck, mosi => mosi, ss_n => ss_int,
                  sample => sample, busy => busy, done => done);

    -- Приймач (MISO)
    u_rx : entity work.spi_master_rx
        port map (clk => clk, rst => rst, ss_n => ss_int, sample => sample,
                  miso => miso, rx_data => rx_data, rx_valid => rx_valid);

    ss_n <= ss_int;

end architecture rtl;
