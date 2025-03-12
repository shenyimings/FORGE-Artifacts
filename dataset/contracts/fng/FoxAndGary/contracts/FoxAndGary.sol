// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./ERC20.sol";
import "./Owned.sol";

contract FoxAndGary is ERC20, Owned {

    event FeeUpdated(uint256 newFeeValue);
    event TreasuryUpdated(address newTreasuryAddress);

    uint256 constant public INITIAL_SUPPLY = 10_000_000_000_000 * (10 ** 18);
    uint256 constant public MAX_FEE = 2_00;
    uint256 public fee = 2_00;
    address public treasury;

    constructor() ERC20("FoxAndGary", "FNG", 18) Owned(msg.sender) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function transfer(address _to, uint256 _amount) public override returns (bool) {
        balanceOf[msg.sender] -= _amount;

        unchecked {
            balanceOf[_to] += (_amount - _processFee(msg.sender, _amount));
        }

        emit Transfer(msg.sender, _to, _amount);

        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        uint256 allowed = allowance[_from][msg.sender];

        if (allowed != type(uint256).max) allowance[_from][msg.sender] = allowed - _amount;

        balanceOf[_from] -= _amount;

        unchecked {
            balanceOf[_to] += (_amount - _processFee(_from, _amount));
        }

        emit Transfer(_from, _to, _amount);

        return true;
    }

    function _processFee(address _from, uint256 _amount) private returns (uint256 feeAmount) {
        feeAmount = _amount * fee / 100_00;
        if (feeAmount > 0) {
            balanceOf[treasury] += feeAmount;
            emit Transfer(_from, treasury, feeAmount);
        }
    }

    function burn(uint256 _amount) public {
        _burn(msg.sender, _amount);
    }

    function setFee(uint256 _fee) public onlyOwner {
        require(_fee <= MAX_FEE, "fee too high");
        fee = _fee;
        emit FeeUpdated(_fee);
    }

    function setTreasury(address _treasury) public onlyOwner {
        // might be address(0) to burn fees
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }
}
