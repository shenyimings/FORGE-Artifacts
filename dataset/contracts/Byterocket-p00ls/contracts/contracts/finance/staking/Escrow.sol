// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@amxx/hre/contracts/ENSReverseRegistration.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "../../tokens/interfaces.sol";

interface IEscrowReceiver {
    function onEscrowRelease(uint256) external;
}

/// @custom:security-contact security@p00ls.com
contract Escrow is AccessControl, Multicall {
    using SafeCast for uint256;

    bytes32 public constant ESCROW_MANAGER_ROLE = keccak256("ESCROW_MANAGER_ROLE");

    /*****************************************************************************************************************
     *                                                    Storage                                                    *
     *****************************************************************************************************************/
    // fits into a single slot
    struct Details {
        uint48  lastUpdate;
        uint48  deadline;
        address beneficiary;
    }

    mapping (IERC20 => Details) public manifests;

    /*****************************************************************************************************************
     *                                                    Events                                                     *
     *****************************************************************************************************************/
    event NewStaking(IERC20 indexed token, address indexed beneficiary, uint48 start, uint48 stop);

    /*****************************************************************************************************************
     *                                                   Functions                                                   *
     *****************************************************************************************************************/
    constructor(address _admin)
    {
        _grantRole(DEFAULT_ADMIN_ROLE,  _admin);
        _grantRole(ESCROW_MANAGER_ROLE, _admin);
    }

    function configure(IP00lsTokenCreator token, uint48 start, uint48 stop)
        external
        onlyRole(ESCROW_MANAGER_ROLE)
    {
        _configure(token, start, stop, address(token.xCreatorToken()));
    }

    function configureWithBeneficary(IERC20 token, uint48 start, uint48 stop, address beneficiary)
        external
        onlyRole(ESCROW_MANAGER_ROLE)
    {
        try IP00lsTokenCreator(address(token)).xCreatorToken() returns (IP00lsTokenXCreator tokenXCreator) {
            // if the token is an IP00lsTokenCreator, then the beneficiary must be the corresponding tokenXcreator
            require(beneficiary == address(tokenXCreator));
        } catch {
            // it the token is not an IP00lsTokenCreator, its ok to have another beneficiary
        }

        _configure(token, start, stop, beneficiary);
    }

    function _configure(IERC20 token, uint48 start, uint48 stop, address beneficiary)
        internal
    {
        release(token); // this will reset if previous schedule is over

        require(start > 0, "Invalid input: start should be non 0");
        require(stop >= start, "Invalid input: start must be before stop");

        Details storage manifest = manifests[token];
        require(manifest.lastUpdate == 0, "Release already active");

        manifest.lastUpdate  = start;
        manifest.deadline    = stop;
        manifest.beneficiary = beneficiary;

        emit NewStaking(token, beneficiary, start, stop);
    }

    function releasable(IERC20 token)
        public
        view
        returns (uint256)
    {
        Details memory manifest = manifests[token];

        if (manifest.lastUpdate == 0 || block.timestamp <= manifest.lastUpdate)
        {
            return 0;
        }
        else if (block.timestamp < manifest.deadline)
        {
            uint48 step  = uint48(block.timestamp) - manifest.lastUpdate;
            uint48 total = manifest.deadline       - manifest.lastUpdate;
            return Math.mulDiv(token.balanceOf(address(this)), step, total);
        }
        else
        {
            return token.balanceOf(address(this));
        }
    }

    function release(IERC20 token)
        public
        returns (uint256)
    {
        Details memory manifest = manifests[token];

        // release tokens
        uint256 toRelease = releasable(token);
        if (toRelease > 0)
        {
            manifests[token].lastUpdate = uint48(block.timestamp);

            SafeERC20.safeTransfer(token, manifest.beneficiary, toRelease);
            if (Address.isContract(manifest.beneficiary))
            {
                try IEscrowReceiver(manifest.beneficiary).onEscrowRelease(toRelease) {}
                catch {}
            }
        }

        // reset once schedule is complete
        if (manifest.lastUpdate != 0 && manifest.deadline <= block.timestamp)
        {
            delete manifests[token];
        }

        return toRelease;
    }

    function setName(address ensregistry, string calldata ensname)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        ENSReverseRegistration.setName(ensregistry, ensname);
    }
}
