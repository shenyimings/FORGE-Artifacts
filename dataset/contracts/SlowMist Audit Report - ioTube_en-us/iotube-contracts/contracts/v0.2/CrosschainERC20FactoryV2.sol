// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./CrosschainERC20V2.sol";
import "./CrosschainERC20V2Pair.sol";

contract CrosschainERC20FactoryV2 is Ownable {
    using Address for address;

    event NewCrosschainERC20(
        address indexed token,
        string name,
        string symbol,
        uint8 decimals
    );
    event NewCrosschainERC20Pair(
        address indexed crosschainToken,
        address indexed token,
        address indexed pair
    );
    event MinterDAOSet(address indexed dao);

    address public minterDAO;

    constructor(address _minterDAO) {
        minterDAO = _minterDAO;
        emit MinterDAOSet(_minterDAO);
    }

    function setMinterDAO(address _minterDAO) external onlyOwner {
        minterDAO = _minterDAO;
        emit MinterDAOSet(_minterDAO);
    }

    function createCrosschainERC20(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) external onlyOwner returns (address) {
        CrosschainERC20V2 cc = new CrosschainERC20V2(minterDAO, _name, _symbol, _decimals);
        emit NewCrosschainERC20(address(cc), _name, _symbol, _decimals);

        return address(cc);
    }

    function createCrosschainERC20Pair(
        address _crosschainToken,
        uint8 _crosschainTokenDecimals,
        address _token,
        uint8 _tokenDecimals
    ) external onlyOwner returns (address) {
        CrosschainERC20V2Pair wrapper = new CrosschainERC20V2Pair(_crosschainToken, _crosschainTokenDecimals, _token, _tokenDecimals, owner());
        emit NewCrosschainERC20Pair(_crosschainToken, _token, address(wrapper));

        // TODO add to minter dao? need owner!
        return address(wrapper);
    }
}
