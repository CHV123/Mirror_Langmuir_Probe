/// MLP driver
///
/// (c) Koheron

#ifndef __DRIVERS_MLP_HPP__
#define __DRIVERS_MLP_HPP__

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

//constexpr uint32_t dac_size = mem::dac_range/sizeof(uint32_t);


class MLP
{
public:
  MLP(Context& ctx)
    : ctl(ctx.mm.get<mem::control>())
    , sts(ctx.mm.get<mem::status>())
    , adc_fifo_map(ctx.mm.get<mem::adc_fifo>())
    // , dac_map(ctx.mm.get<mem::dac>()) 
  {
    start_fifo_acquisition();
  }
  
  // Trigger
 
  void trig_pulse() {
    ctl.set_bit<reg::Trigger, 0>();
    ctl.clear_bit<reg::Trigger, 0>();
  }
  
  //  MLP
  void set_led(uint32_t led) {
    ctl.write<reg::led>(led);
  }

  void set_period(uint32_t period) {
    ctl.write<reg::Period>(period);
  }

  void set_acquistion_length(uint32_t acquisition_length) {
    ctl.write<reg::Acqusition_length>(acquisition_length);
  }

  uint32_t get_temperature() {
    uint32_t temp_value = sts.read<reg::Temperature>();
    return temp_value;
  }

  uint32_t get_Isaturation() {
    uint32_t Isat_value = sts.read<reg::Isaturation>();
    return Isat_value;
  }

  uint32_t get_vFloat() {
    uint32_t vFloat_value = sts.read<reg::vFloat>();
    return vFloat_value;
  }

  uint32_t get_Timestamp() {
    uint32_t timestamp_value = sts.read<reg::Timestamp>();
    return timestamp_value;
  }  
  
  //Adc FIFO
  
  uint32_t get_fifo_occupancy() {
    return adc_fifo_map.read<Fifo_regs::rdfo>();
  }
  
  void reset_fifo() {
    adc_fifo_map.write<Fifo_regs::rdfr>(0x000000A5);
  }
  
  uint32_t read_fifo() {
    return adc_fifo_map.read<Fifo_regs::rdfd>();
  }
  
  uint32_t get_fifo_length() {
    return (adc_fifo_map.read<Fifo_regs::rlr>() & 0x3FFFFF) >> 2;
  }
  
  void wait_for(uint32_t n_pts) {
    do {} while (get_fifo_length() < n_pts);
  }
  
  
  void start_fifo_acquisition();

   // Function to return the buffer length
  uint32_t get_buffer_length() {
    return collected;
  }
  
  // Function to return data
  std::vector<uint32_t>& get_MLP_data() {
    
    //ctx.log<INFO>("Found Data");
    //ctx.log<INFO>("adc_data size: %d", adc_data.size());
    
    dataAvailable = false;
   
    return adc_data;
  }
  
  
private:
  //Context& ctx;
  Memory<mem::control>& ctl;
  Memory<mem::status>& sts;
  Memory<mem::adc_fifo>& adc_fifo_map;

  std::vector<uint32_t> adc_data;
  //std::vector<uint32_t> empty_vector;
  
  std::atomic<bool> fifo_acquisition_started{false};
  
  std::thread fifo_thread;
  // Member functions
  void fifo_acquisition_thread();
  uint32_t fill_buffer(uint32_t);
  // Member variables
  bool dataAvailable = false;
  std::atomic<uint32_t> collected{0};         //number of currently collected data
};

inline void MLP::start_fifo_acquisition() {
  if (! fifo_acquisition_started) {
    fifo_thread = std::thread{&MLP::fifo_acquisition_thread, this};
    fifo_thread.detach();
  }
}

inline void MLP::fifo_acquisition_thread() {
  constexpr auto fifo_sleep_for = std::chrono::microseconds(60);
  fifo_acquisition_started = true;
  //ctx.log<INFO>("Starting fifo acquisition");
  adc_data.reserve(16777216);
  adc_data.resize(0);
  //empty_vector.resize(0);
  
  uint32_t dropped=0;
  
  // While loop to reserve the number of samples needed to be collected
  while (fifo_acquisition_started){
    if (collected == 0){
      // Checking that data has not yet been collected
      if ((dataAvailable == false) && (adc_data.size() > 0)){
	// Sleep to avoid a race condition while data is being transferred
	std::this_thread::sleep_for(fifo_sleep_for);
	// Clearing vector back to zero
	adc_data.resize(0);
      }
    }
    
    dropped = fill_buffer(dropped);
    
  }// While loop
}

// Member function to fill buffer array
inline uint32_t MLP::fill_buffer(uint32_t dropped) {
    // Retrieving the number of samples to collect
  uint32_t samples=get_fifo_length();
  
  // Checking for dropped samples
  if (samples >= 32768){  	
    dropped += 1;
  }
  // Collecting samples in buffer
  if (samples > 0) {
    for (size_t i=0; i < samples; i++){	  
      adc_data.push_back(read_fifo());	  
      collected = collected + 1;
    }
  }
  // if statement for setting the acquisition completed flag
  if (samples == 0) {
    dataAvailable = true;
    collected = 0;
    dropped = 0;
  }
  return dropped;
}

#endif // __DRIVERS_MLP_HPP__
