/// PCS driver
///
/// (c) Koheron

#ifndef __DRIVERS_PCS_HPP__
#define __DRIVERS_PCS_HPP__

#include <atomic>
#include <thread>
#include <chrono>

#include <context.hpp>

// http://www.xilinx.com/support/documentation/ip_documentation/axi_fifo_mm_s/v4_1/pg080-axi-fifo-mm-s.pdf
namespace Fifo_regs {
    constexpr uint32_t rdfr = 0x18;
    constexpr uint32_t rdfo = 0x1C;
    constexpr uint32_t rdfd = 0x20;
    constexpr uint32_t rlr = 0x24;
}

constexpr uint32_t dac_size = mem::dac_range/sizeof(uint32_t);


class PCS
{
  public:
    PCS(Context& ctx)
    : ctl(ctx.mm.get<mem::control>())
    , sts(ctx.mm.get<mem::status>())
    // , adc_fifo_map(ctx.mm.get<mem::adc_fifo>())
    // , dac_map(ctx.mm.get<mem::dac>())
    {
        start_fifo_acquisition();
    }

    // Trigger


    void trig_pulse() {
        ctl.set_bit<reg::trigger, 0>();
        ctl.clear_bit<reg::trigger, 0>();
    }

    // PCS generator

    void set_Isat(uint32_t Isat) {
        ctl.write<reg::Isat>(Isat);
    }

    void set_Temperture(uint32_t Temperture) {
        ctl.write<reg::Temperture>(Temperture);
    }

    void set_Vfloating(uint32_t Vfloating) {
        ctl.write<reg::Vfloating>(Vfloating);
    }

    void set_Resistence(uint32_t Resistence) {
        ctl.write<reg::Resistence>(Resistence);
    }

    void set_Switch(uint32_t Switch) {
        ctl.write<reg::Switch>(Switch);
    }

    uint32_t get_Current() {
        uint32_t Current_value = sts.read<reg::Current>();
        return Current_value;
    } 

    // void set_dac_data(const std::array<uint32_t, dac_size>& data) {
    //     dac_map.write_array(data);
    // }

    // Adc FIFO

    // uint32_t get_fifo_occupancy() {
    //     return adc_fifo_map.read<Fifo_regs::rdfo>();
    // }

    // void reset_fifo() {
    //     adc_fifo_map.write<Fifo_regs::rdfr>(0x000000A5);
    // }

    // uint32_t read_fifo() {
    //     return adc_fifo_map.read<Fifo_regs::rdfd>();
    // }

    // uint32_t get_fifo_length() {
    //     return (adc_fifo_map.read<Fifo_regs::rlr>() & 0x3FFFFF) >> 2;
    // }

    // void wait_for(uint32_t n_pts) {
    //     do {} while (get_fifo_length() < n_pts);
    // }



    // const auto& get_fifo_buffer() {
    //     return fifo_buffer;
    // }

    void start_fifo_acquisition();

  private:
    Memory<mem::control>& ctl;
    Memory<mem::status>& sts;
    // Memory<mem::adc_fifo>& adc_fifo_map;
    // Memory<mem::dac>& dac_map;



    // std::vector<uint32_t> adc_data;


    // static constexpr uint32_t fifo_buff_size = 1024;

    // std::array<uint32_t, fifo_buff_size> fifo_buffer;

    std::atomic<bool> fifo_acquisition_started{false};
    // std::atomic<uint32_t> fifo_buff_idx{0};

    std::thread fifo_thread;
    void fifo_acquisition_thread();

};

inline void PCS::start_fifo_acquisition() {
    if (! fifo_acquisition_started) {
        // fifo_buffer.fill(0);
        fifo_thread = std::thread{&PCS::fifo_acquisition_thread, this};
        fifo_thread.detach();
    }
}

inline void PCS::fifo_acquisition_thread()
{
    constexpr auto fifo_sleep_for = std::chrono::microseconds(5000);

    fifo_acquisition_started = true;

    while (fifo_acquisition_started) {
        // const uint32_t n_pts = get_fifo_length();

        // for (size_t i = 0; i < n_pts; i++) {
        //     fifo_buffer[fifo_buff_idx] = read_fifo();
        //     fifo_buff_idx = (fifo_buff_idx + 1) % fifo_buff_size;
        // }
        std::this_thread::sleep_for(fifo_sleep_for);
    }
}

#endif // __DRIVERS_PCS_HPP__
