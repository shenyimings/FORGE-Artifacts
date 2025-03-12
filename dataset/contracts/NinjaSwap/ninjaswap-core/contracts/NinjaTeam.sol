// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
contract NinjaTeam {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    address public Donatello; // 0.3x
    address public Raphael;  // 0.3x
    address public Michelangelo; //0.3x
    address public Leonardo; //0.1x
    IERC20 public NINJA;

    constructor(
            address  _Donatello,
            address  _Raphael,
            address  _Michelangelo,
            address  _Leonardo,
            IERC20 _ninja

    ) public {
            Donatello = _Donatello;
            Raphael = _Raphael;
            Michelangelo = _Michelangelo;
            Leonardo = _Leonardo;
            NINJA = _ninja;
    }

      modifier onlyTeam() {
        require(
            Donatello == msg.sender || Raphael == msg.sender || Michelangelo == msg.sender || Leonardo  == msg.sender,
            "No Permission"
        );
        _;
    }
    function updateDonatelloAdd(address _Donatello) public onlyTeam {
        Donatello = _Donatello;
    }
    function updateRaphaelAdd(address _Raphael) public onlyTeam {
        Raphael = _Raphael;
    }
    function updateMichelangeloAdd(address _Michelangelo) public onlyTeam {
        Michelangelo = _Michelangelo;
    }
    function updateLeonardoAdd(address _Leonardo) public onlyTeam {
        Leonardo = _Leonardo;
    }

     function withdrawNINJA() public onlyTeam {
        uint256 balance = NINJA.balanceOf(address(this));
        uint256 x33 = balance.mul(33).div(100);
        uint256 x34 = balance.sub(x33.mul(2));
        NINJA.safeTransfer(Donatello, x33);
        NINJA.safeTransfer(Raphael, x33);
        NINJA.safeTransfer(Michelangelo, x34);
    }

    function updateNinjaAdd(address newNinja) public onlyTeam {
        // incase of change Ninja
        require(newNinja != address(0), "Ninja Token address invalid");
        NINJA = IERC20(newNinja);
    }
    function availableNinja() public view returns (uint256) {
        return NINJA.balanceOf(address(this));
    }

}
