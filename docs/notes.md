# Design Notes

## Decisions Log

| Date       | Topic              | Decision                                      | Rationale                          |
|------------|--------------------|-----------------------------------------------|-------------------------------------|
| 2026-02-01 | Project Init       | Created directory structure                   | Organize RTL, sim, and docs cleanly |
| 2026-02-01 | ISA                | RV32I base only (no M/C extensions initially) | Keep scope minimal for first tapeout |
| 2026-02-01 | Template           | Cloned efabless/caravel_user_project          | Official Efabless MPW harness        |
| 2026-02-01 | Interface          | Locked rv32_core top-level interface          | Fixed contract for all modules       |

---

## Open Issues

- [x] Decide on memory sizes (instruction/data SRAM depth) → 4KB each
- [ ] Choose JTAG clock frequency relative to core clock
- [ ] Define BIST coverage requirements
- [x] Select target PDK → SKY130
- [x] Install Git ✓
- [x] Install Python 3 ✓
- [ ] Install Docker Desktop
- [ ] Install sv2v

---

## Design Notes

### Core Architecture
- Single-cycle design chosen for simplicity
- All instructions complete in one clock cycle
- No pipeline hazards to handle

### Debug Considerations
- JTAG TAP will be active even during reset
- Debug Module needs separate clock domain handling

### BIST Strategy
- March C- algorithm provides good fault coverage
- BIST runs at power-on before normal operation

---

## References & Resources

- *Add links to useful documentation, papers, or examples here*

---

## Scratchpad

*Use this section for quick notes during development*
