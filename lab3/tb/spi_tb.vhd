--------------------------------------------------------------------------------
-- Тестбенч    : tb_spi
-- Призначення : Функціональна верифікація SPI Master (spi_top), режим 3.
--
-- Що робить тестбенч:
--   * генерує CLK 25 МГц та сигнал RESET;
--   * містить поведінкову модель SPI Slave (режим 3): по кожному спаду
--     SCK (ведучий фронт) виставляє на MISO черговий біт свого байта
--     (MSB first), по фронту SCK (задній фронт) читає MOSI;
--   * лічить фронти SCK у кожному кадрі і перевіряє, що їх рівно 8,
--     а у стані спокою SCK = '1' (CPOL = 1);
--   * ТЕСТ 1 (Tx, MOSI): Master передає 0xB2, 0x4D, 0x00, 0xFF -
--     перевіряється байт, прийнятий моделлю Slave;
--   * ТЕСТ 2 (Rx, MISO): Slave передає 0x1C, 0xE7, 0x5B, 0x90 -
--     перевіряється rx_data Master;
--   * ТЕСТ 3: повнодуплексний обмін 0xA6 (Master) <-> 0x3D (Slave).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_spi is
end entity tb_spi;

architecture sim of tb_spi is
    constant CLK_FREQ : positive := 25_000_000;
    constant SCK_FREQ : positive := 500_000;
    constant CLK_PER  : time     := 40 ns;          -- 25 МГц

    -- Сигнали DUT
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal start    : std_logic := '0';
    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;
    signal busy     : std_logic;
    signal done     : std_logic;
    signal sck      : std_logic;
    signal mosi     : std_logic;
    signal miso     : std_logic;
    signal ss_n     : std_logic;

    -- Модель Slave
    signal s_tx_byte : std_logic_vector(7 downto 0) := x"00";  -- що Slave передає
    signal s_rx_byte : std_logic_vector(7 downto 0) := x"00";  -- що Slave прийняв
    signal s_miso    : std_logic := '0';
    signal s_frames  : natural := 0;
    signal sck_edges : natural := 0;   -- фронтів SCK в останньому кадрі
    signal sck_idle_err : boolean := false;

    -- Захоплення результатів приймача Master
    signal rx_last  : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_cnt   : natural := 0;

    signal sim_done : boolean := false;

    type byte_arr is array (natural range <>) of std_logic_vector(7 downto 0);
    constant TX_VECTORS : byte_arr := (x"B2", x"4D", x"00", x"FF");
    constant RX_VECTORS : byte_arr := (x"1C", x"E7", x"5B", x"90");
begin

    ---------------------------------------------------------------------------
    -- Тестований пристрій
    ---------------------------------------------------------------------------
    dut : entity work.spi_top
        generic map (CLK_FREQ => CLK_FREQ, SCK_FREQ => SCK_FREQ)
        port map (clk => clk, rst => rst, start => start, tx_data => tx_data,
                  rx_data => rx_data, rx_valid => rx_valid, busy => busy, done => done,
                  sck => sck, mosi => mosi, miso => miso, ss_n => ss_n);

    -- MISO у третьому стані, коли Slave не вибраний
    miso <= s_miso when ss_n = '0' else 'Z';

    ---------------------------------------------------------------------------
    -- Генератор тактового сигналу
    ---------------------------------------------------------------------------
    clk <= not clk after CLK_PER / 2 when not sim_done else '0';

    ---------------------------------------------------------------------------
    -- Поведінкова модель SPI Slave, режим 3 (CPOL = 1, CPHA = 1)
    ---------------------------------------------------------------------------
    slave : process
        variable sh_tx : std_logic_vector(7 downto 0);
        variable sh_rx : std_logic_vector(7 downto 0);
        variable edges : natural;
    begin
        wait until falling_edge(ss_n);
        sh_tx  := s_tx_byte;
        sh_rx  := (others => '0');
        edges  := 0;
        loop
            wait until falling_edge(sck) or rising_edge(ss_n);
            exit when ss_n = '1';
            s_miso <= sh_tx(7);                 -- біт по спаду SCK (ведучий фронт)
            sh_tx  := sh_tx(6 downto 0) & '0';
            wait until rising_edge(sck) or rising_edge(ss_n);
            exit when ss_n = '1';
            sh_rx := sh_rx(6 downto 0) & mosi;  -- вибірка MOSI по фронту SCK
            edges := edges + 1;
        end loop;
        s_rx_byte <= sh_rx;
        sck_edges <= edges;
        s_frames  <= s_frames + 1;
    end process slave;

    -- Контроль полярності SCK у стані спокою (CPOL = 1)
    idle_check : process (clk)
    begin
        if rising_edge(clk) and rst = '0' then
            if ss_n = '1' and sck /= '1' then
                sck_idle_err <= true;
            end if;
        end if;
    end process idle_check;

    -- Лічильник прийнятих Master байтів
    rx_capture : process (clk)
    begin
        if rising_edge(clk) then
            if rx_valid = '1' then
                rx_last <= rx_data;
                rx_cnt  <= rx_cnt + 1;
            end if;
        end if;
    end process rx_capture;

    ---------------------------------------------------------------------------
    -- Основний сценарій
    ---------------------------------------------------------------------------
    stimulus : process
        variable err_cnt : natural := 0;

        -- Один кадр SPI: Master передає m, Slave передає s
        procedure xfer (constant m : in std_logic_vector(7 downto 0);
                        constant s : in std_logic_vector(7 downto 0)) is
        begin
            s_tx_byte <= s;
            wait until rising_edge(clk);
            tx_data <= m;
            start   <= '1';
            wait until rising_edge(clk);
            start   <= '0';
            wait until done = '1';
            wait for 1 us;
        end procedure;
    begin
        rst <= '1';
        wait for 200 ns;
        wait until rising_edge(clk);
        rst <= '0';
        wait for 2 us;

        -- ТЕСТ 1: передача MOSI
        report "=== TEST 1: Tx - master sends on MOSI ===";
        for i in TX_VECTORS'range loop
            xfer(TX_VECTORS(i), x"00");
            if s_rx_byte = TX_VECTORS(i) and sck_edges = 8 then
                report "TEST1 OK  : MOSI 0x" & to_hstring(TX_VECTORS(i)) &
                       " -> slave got 0x" & to_hstring(s_rx_byte) &
                       ", SCK pulses = " & integer'image(sck_edges);
            else
                report "TEST1 FAIL: slave got 0x" & to_hstring(s_rx_byte) &
                       ", SCK pulses = " & integer'image(sck_edges) severity error;
                err_cnt := err_cnt + 1;
            end if;
            wait for 4 us;
        end loop;

        -- ТЕСТ 2: прийом MISO
        report "=== TEST 2: Rx - master receives on MISO ===";
        for i in RX_VECTORS'range loop
            xfer(x"00", RX_VECTORS(i));
            if rx_cnt = TX_VECTORS'length + i + 1 and rx_last = RX_VECTORS(i) then
                report "TEST2 OK  : MISO 0x" & to_hstring(RX_VECTORS(i)) &
                       " -> rx_data = 0x" & to_hstring(rx_last);
            else
                report "TEST2 FAIL: expected 0x" & to_hstring(RX_VECTORS(i)) &
                       ", got 0x" & to_hstring(rx_last) severity error;
                err_cnt := err_cnt + 1;
            end if;
            wait for 2 us;
        end loop;

        -- ТЕСТ 3: повний дуплекс
        report "=== TEST 3: full duplex exchange ===";
        xfer(x"A6", x"3D");
        if s_rx_byte = x"A6" and rx_last = x"3D" then
            report "TEST3 OK  : master 0xA6 -> slave, slave 0x3D -> master";
        else
            report "TEST3 FAIL: slave got 0x" & to_hstring(s_rx_byte) &
                   ", master got 0x" & to_hstring(rx_last) severity error;
            err_cnt := err_cnt + 1;
        end if;
        if not sck_idle_err then
            report "TEST3 OK  : SCK = 1 while SS_n = 1 (CPOL = 1)";
        else
            report "TEST3 FAIL: SCK not idle high" severity error;
            err_cnt := err_cnt + 1;
        end if;
        wait for 5 us;

        if err_cnt = 0 then
            report "=== ALL TESTS PASSED ===";
        else
            report "=== ERRORS: " & integer'image(err_cnt) & " ===" severity error;
        end if;
        sim_done <= true;
        wait for 100 ns;
        finish;
    end process stimulus;

end architecture sim;
