--------------------------------------------------------------------------------
-- Модуль      : spi_master_rx
-- Призначення : Приймач SPI Master (лінія MISO), режим 3 (CPOL = 1, CPHA = 1).
--
-- Логіка роботи:
--   1. Вхід MISO проходить через 2-тригерний синхронізатор.
--   2. IDLE : очікування активного SS_n = '0'.
--   3. SHIFT: по кожному стробу sample (задній фронт SCK 0 -> 1) біт MISO
--             вдвигається у зсувний регістр справа (MSB приходить першим).
--   4. DONE : після 8 біт rx_data <= shreg, імпульс rx_valid;
--             повернення в IDLE, коли SS_n знову = '1'.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master_rx is
    port (
        clk      : in  std_logic;                     -- системний такт
        rst      : in  std_logic;                     -- синхронне скидання
        ss_n     : in  std_logic;                     -- вибір Slave (від передавача)
        sample   : in  std_logic;                     -- строб фронту SCK
        miso     : in  std_logic;                     -- дані Slave -> Master
        rx_data  : out std_logic_vector(7 downto 0);  -- прийнятий байт
        rx_valid : out std_logic                      -- імпульс 1 такт: байт готовий
    );
end entity spi_master_rx;

architecture rtl of spi_master_rx is
    type state_t is (S_IDLE, S_SHIFT, S_DONE);
    signal state : state_t := S_IDLE;

    signal miso_meta, miso_sync : std_logic := '0';                       -- синхронізатор
    signal shreg   : std_logic_vector(7 downto 0) := (others => '0');     -- зсувний регістр
    signal bit_cnt : natural range 0 to 7 := 0;                           -- кількість біт
begin

    sync : process (clk)
    begin
        if rising_edge(clk) then
            miso_meta <= miso;
            miso_sync <= miso_meta;
        end if;
    end process sync;

    fsm : process (clk)
    begin
        if rising_edge(clk) then
            rx_valid <= '0';

            if rst = '1' then
                state   <= S_IDLE;
                bit_cnt <= 0;
                shreg   <= (others => '0');
                rx_data <= (others => '0');
            else
                case state is

                    -- Очікування початку обміну
                    when S_IDLE =>
                        if ss_n = '0' then
                            bit_cnt <= 0;
                            state   <= S_SHIFT;
                        end if;

                    -- Вибірка MISO по фронту SCK
                    when S_SHIFT =>
                        if sample = '1' then
                            shreg <= shreg(6 downto 0) & miso_sync;
                            if bit_cnt = 7 then
                                state <= S_DONE;
                            else
                                bit_cnt <= bit_cnt + 1;
                            end if;
                        end if;

                    -- Видача результату і очікування SS_n = '1'
                    when S_DONE =>
                        if ss_n = '1' then
                            rx_data  <= shreg;
                            rx_valid <= '1';
                            state    <= S_IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process fsm;

end architecture rtl;
