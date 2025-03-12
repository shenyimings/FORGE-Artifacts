// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/ERC20.sol)

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

/**
 * @title DEEPToken
 */
contract DeepToken is ERC20Capped, Ownable {
    // Minters of DeepToken
    mapping(address => bool) public minters;

    // The maximum number of minting tokens from minters
    mapping(address => uint256) public allocation;

    // The number of token minted from minters
    mapping(address => uint256) public minted;

    constructor() ERC20Capped(1e26) ERC20("DEEPToken", "DEEP") {}

    modifier onlyMinter() {
        require(minters[msg.sender], "Invalid minter address");
        _;
    }

    /////////////////////////
    //// Owner Functions ////
    /////////////////////////

    function setMinter(address _account, bool _isMinter) public onlyOwner {
        require(_account != address(0), "Invalid address");
        minters[_account] = _isMinter;
    }

    function setAllocation(address _account, uint256 _amount) public onlyOwner {
        require(_account != address(0), "Invalid address");
        allocation[_account] = _amount;
    }

    /////////////////////////
    //// Minter Functions ///
    /////////////////////////

    function mint(address _account, uint256 _amount) public onlyMinter {
        require(
            minted[msg.sender] + _amount <= allocation[msg.sender],
            "Not able to mint more tokens"
        );
        minted[msg.sender] += _amount;
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) public onlyMinter {
        _burn(_account, _amount);
    }
}
