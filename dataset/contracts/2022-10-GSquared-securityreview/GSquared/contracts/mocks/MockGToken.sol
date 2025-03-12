// SPDX-License-Identifier: AGPLv3
pragma solidity >=0.8.0;

import {ERC20} from "../solmate/src/tokens/ERC20.sol";
import {Owned} from "../solmate/src/auth/Owned.sol";
import "../common/Constants.sol";

contract MockGToken is ERC20, Owned, Constants {
    uint256 public utilisationthreshold = 5000;

    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol, 18)
        Owned(msg.sender)
    {}

    function mint(
        address _account,
        uint256 _factor,
        uint256 _amount
    ) external {
        _factor;
        require(_account != address(0), "Account is empty.");
        require(_amount > 0, "amount is less than zero.");
        _mint(_account, _amount);
    }

    function burn(
        address _account,
        uint256 _factor,
        uint256 _amount
    ) external {
        _factor;
        require(_account != address(0), "Account is empty.");
        require(_amount > 0, "amount is less than zero.");
        _burn(_account, _amount);
    }

    function factor() public view returns (uint256) {
        return factor(totalAssets());
    }

    function factor(uint256 _totalAssets) public view returns (uint256) {
        if (totalSupply == 0) {
            return getInitialBase();
        }

        if (_totalAssets > 0) {
            return (totalSupply * (BASE)) / _totalAssets;
        }

        return 0;
    }

    function burnAll(address _account) external {
        _burn(_account, balanceOf[_account]);
    }

    function totalAssets() public view returns (uint256) {
        return totalSupply;
    }

    function getPricePerShare() external view returns (uint256) {}

    function getShareAssets(uint256 _shares) external pure returns (uint256) {
        return _shares;
    }

    function getAssets(address _account) external view returns (uint256) {
        return balanceOf[_account];
    }

    function getInitialBase() internal pure virtual returns (uint256) {
        return BASE;
    }
}
