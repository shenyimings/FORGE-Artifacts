// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Ingest Master Contract
 * @author Origin Protocol Inc
 */

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./IngestImpl.sol";
import "../governance/Governable.sol";

contract IngestMaster is Governable, Initializable {
    address midProxy;
    address public collector;

    event NewCollector(
        address indexed newCollector,
        address indexed oldCollector
    );

    using SafeERC20 for IERC20;
    using Clones for address;

    function initialize(address _midProxy) public initializer onlyGovernor {
        midProxy = _midProxy;
        collector = msg.sender;
        require(midProxy != address(0), "IngestMaster: midProxy must set");
    }

    function getAddress(bytes32 salt) external view returns (address) {
        require(midProxy != address(0), 'MidProxy must be set');
        return midProxy.predictDeterministicAddress(salt);
    }

    function collect(
        bytes32 salt,
        address asset,
        uint256 amount
    ) public onlyCollector {
        address payable addr =
            payable(midProxy.predictDeterministicAddress(salt));
        if (!Address.isContract(addr)) {
            address payable new_addr =
                payable(midProxy.cloneDeterministic(salt));
            require(new_addr == addr, "Addresses must match");
        }
        IngestImpl(addr).collect(asset, amount);
    }

    function collectBatch(
        bytes32[] calldata salts,
        address[] calldata assets,
        uint256[] calldata amounts
    ) external onlyCollector {
        uint256 length = salts.length;
        require(length == assets.length, "Assets length must match");
        require(length == amounts.length, "Amounts length must match");
        for (uint256 i = 0; i < length; i++) {
            collect(salts[i], assets[i], amounts[i]);
        }
    }

    function setCollector(address _collector) public onlyGovernor {
        emit NewCollector(_collector, collector);
        collector = _collector;
    }

    modifier onlyCollector() {
        require(collector == msg.sender, "Master: Caller is not the Collector");
        _;
    }
}
