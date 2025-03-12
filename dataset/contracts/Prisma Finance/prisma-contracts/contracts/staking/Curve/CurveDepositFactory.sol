// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "../../dependencies/PrismaOwnable.sol";
import "../../interfaces/ICurveProxy.sol";

interface ICurveDepositToken {
    function initialize(address _gauge) external;
}

/**
    @notice Prisma Curve Factory
    @title Deploys clones of `CurveDepositToken` as directed by the Prisma DAO
 */
contract CurveFactory is PrismaOwnable {
    using Clones for address;

    ICurveProxy public immutable curveProxy;
    address public immutable depositTokenImpl;

    event NewDeployment(address gauge, address depositToken);

    constructor(address _prismaCore, ICurveProxy _curveProxy, address _depositTokenImpl) PrismaOwnable(_prismaCore) {
        curveProxy = _curveProxy;
        depositTokenImpl = _depositTokenImpl;
    }

    /**
        @dev After calling this function, the owner should also call `Treasury.registerReceiver`
             to enable PRISMA emissions on the newly deployed `CurveDepositToken`
     */
    function deployNewInstance(address gauge) external onlyOwner {
        address depositToken = depositTokenImpl.cloneDeterministic(bytes32(bytes20(gauge)));

        ICurveDepositToken(depositToken).initialize(gauge);
        curveProxy.setPerGaugeApproval(depositToken, gauge);
        // TODO enable PRISMA emissions

        emit NewDeployment(gauge, depositToken);
    }

    function getDepositToken(address gauge) external view returns (address) {
        return Clones.predictDeterministicAddress(depositTokenImpl, bytes32(bytes20(gauge)));
    }
}
