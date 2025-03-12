pragma solidity ^0.7.6;

library LixirErrors {
  function require_INSUFFICIENT_BALANCE(bool cond) internal pure {
    require(cond, 'BALANCE');
  }

  function require_INSUFFICIENT_ALLOWANCE(bool cond) internal pure {
    require(cond, 'ALLOWANCE');
  }

  function require_PERMIT_EXPIRED(bool cond) internal pure {
    require(cond, 'PERMIT_EXPIRED');
  }

  function require_INVALID_SIGNATURE(bool cond) internal pure {
    require(cond, 'INVALID_SIG');
  }

  function require_XFER_ZERO_ADDRESS(bool cond) internal pure {
    require(cond, 'XFER_ZERO_ADDRESS');
  }

  function require_INSUFFICIENT_INPUT_AMOUNT(bool cond) internal pure {
    require(cond, 'INPUT_AMOUNT');
  }

  function require_INSUFFICIENT_OUTPUT_AMOUNT(bool cond) internal pure {
    require(cond, 'OUTPUT_AMOUNT');
  }
}
