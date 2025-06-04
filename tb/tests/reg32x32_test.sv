// /tb/tests/reg32x32_test.sv
class reg32x32_test extends uvm_test;

  reg32x32_env env;

  function new(string name = "reg32x32_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = reg32x32_env::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    uvm_phase::get().raise_objection(this);
    reg32x32_sequence seq;
    seq = reg32x32_sequence::type_id::create("seq");
    seq.start(env.sequencer);
    uvm_phase::get().drop_objection(this);
  endtask
endclass
