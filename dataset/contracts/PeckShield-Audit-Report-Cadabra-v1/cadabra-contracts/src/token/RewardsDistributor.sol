// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;
import "@layerzerolabs/solidity-examples/token/oft/IOFT.sol";
import "openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import "openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface LzApp {
    function lzEndpoint() external view returns (address);
}
interface ILayerZeroEndpoint {
    function getChainId() external view returns (uint16);
}

/**
 * @dev The purpose of this contract is to distribute ABRA token rewards between instances of RewardsSource in all
 * supported chains
 */
contract RewardsDistributor is AccessControlUpgradeable, UUPSUpgradeable {
    uint public constant SEND_GAS = 190000;
    bytes public constant adapterParams = abi.encodePacked(uint16(1), SEND_GAS);
    bytes32 public constant DISTRIBUTE_ROLE = keccak256("DISTRIBUTE_ROLE");
    bytes32 public constant UPGRADE_ROLE = keccak256("UPGRADE_ROLE");

    address public immutable ABRA;
    uint16 public immutable CHAIN_ID;

    uint public totalDebt;
    mapping(uint16 => uint) public debts;

    constructor(address _abra) {
        ABRA = _abra;
        CHAIN_ID = ILayerZeroEndpoint(LzApp(_abra).lzEndpoint()).getChainId() + 100; // magic LayerZero number
    }

    function initialize() public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function available() external view returns (uint) {
        return IERC20(ABRA).balanceOf(address(this)) - totalDebt;
    }

    function distribute(
        uint16[] memory chains,
        uint[] memory amounts
    ) external onlyRole(DISTRIBUTE_ROLE) {
        uint chainsLength = chains.length;
        require(
            chainsLength == amounts.length,
            "RewardsDistributor: arrays length not match"
        );
        uint _totalDebt = totalDebt;
        for (uint i = 0; i < chainsLength; i++) {
            uint amount = amounts[i];
            debts[chains[i]] += amount;
            _totalDebt += amount;
        }
        require(
            _totalDebt <= IERC20(ABRA).balanceOf(address(this)),
            "RewardsDistributor: not enough balance"
        );
        totalDebt = _totalDebt;
    }

    function estimateSendFee(
        uint16[] memory chains,
        address[] memory addresses
    ) external view returns (uint[] memory nativeFees) {
        uint chainsLength = chains.length;
        require(
            chainsLength == addresses.length,
            "RewardsDistributor: arrays length not match"
        );
        nativeFees = new uint[](chainsLength);
        for (uint i = 0; i < chainsLength; i++) {
            uint16 chainId = chains[i];
            if (chainId == CHAIN_ID) continue;
            (uint _nativeFee, ) = IOFT(ABRA).estimateSendFee(
                chainId,
                abi.encodePacked(addresses[i]),
                debts[chainId],
                false,
                adapterParams
            );
            nativeFees[i] = _nativeFee;
        }
    }

    function send(uint16[] memory chains, address[] memory addresses, uint[] memory nativeFees) external {
        uint chainsLength = chains.length;
        require(
            chainsLength == addresses.length && chainsLength == nativeFees.length,
            "RewardsDistributor: arrays length not match"
        );
        uint _totalDebt = totalDebt;
        for (uint i = 0; i < chainsLength; i++) {
            uint16 chainId = chains[i];
            uint amount = debts[chainId];
            debts[chainId] = 0;
            _totalDebt -= amount;
            if (chainId == CHAIN_ID) {
                IERC20(ABRA).transfer(addresses[i], amount);
                continue;
            }
            bytes memory toAddress = abi.encodePacked(addresses[i]);
            IOFT(ABRA).sendFrom{value: nativeFees[i]}(
                address(this),
                chainId,
                toAddress,
                amount,
                payable(address(this)),
                address(0),
                adapterParams
            );
        }
        totalDebt = _totalDebt;
    }

    function _authorizeUpgrade(
        address
    ) internal override onlyRole(UPGRADE_ROLE) {}
}
