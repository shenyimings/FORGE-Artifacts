pragma solidity ^0.4.24;


/**
  @title SafeMathPower
  @notice This library has been inspired by https://github.com/dapphub/ds-math/tree/49b38937c0c0b8af73b05f767a0af9d5e85a1e6c.
  It uses the same functions but with different visibility modifiers and has had unneeded functions removed.

  @dev This library can be used along side OpenZeppelin's SafeMath in the same manner.
*/
library SafeMathPower {
  uint internal constant RAY = 10 ** 27;

  function add(uint x, uint y) private pure returns (uint z) {
    require((z = x + y) >= x);
  }

  function mul(uint x, uint y) private pure returns (uint z) {
    require(y == 0 || (z = x * y) / y == x);
  }

  function rmul(uint x, uint y) private pure returns (uint z) {
    z = add(mul(x, y), RAY / 2) / RAY;
  }

  // This famous algorithm is called "exponentiation by squaring"
  // and calculates x^n with x as fixed-point and n as regular unsigned.
  //
  // It's O(log n), instead of O(n) for naive repeated multiplication.
  //
  // These facts are why it works:
  //
  //  If n is even, then x^n = (x^2)^(n/2).
  //  If n is odd,  then x^n = x * x^(n-1),
  //   and applying the equation for even x gives
  //    x^n = x * (x^2)^((n-1) / 2).
  //
  //  Also, EVM division is flooring and
  //    floor[(n-1) / 2] = floor[n / 2].
  //
  function rpow(uint x, uint n) internal pure returns (uint z) {
    z = n % 2 != 0 ? x : RAY;

    for (n /= 2; n != 0; n /= 2) {
      x = rmul(x, x);

      if (n % 2 != 0) {
        z = rmul(z, x);
      }
    }
  }
}