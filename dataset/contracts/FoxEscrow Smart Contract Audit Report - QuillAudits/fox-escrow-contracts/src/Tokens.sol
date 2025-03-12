// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "OpenZeppelin/openzeppelin-contracts@4.4.0/contracts/access/Ownable.sol";
import "OpenZeppelin/openzeppelin-contracts@4.4.0/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20("1USDT", "1USDT"), Ownable {
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}

contract USDC is ERC20("1USDC", "1USDC"), Ownable {

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}

contract BUSD is ERC20("BUSD", "BUSD"), Ownable {
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}

contract UST is ERC20("Wrapped UST", "UST"), Ownable {
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}

contract DfkItem is ERC20("DFK BLOATER", "BLOATER"), Ownable {

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
