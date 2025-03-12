// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

/**
 * @title AllowList
 * @author malteish, cjentzsch
 * @notice  The AllowList contract is used to manage a list of addresses and attest each address certain attributes.
 *   Examples for possible attributes are: is KYCed, is american, is of age, etc.
 *   One AllowList managed by one entity (e.g. tokenize.it) can manage up to 252 different attributes, and one tier with 5 levels, and can be used by an unlimited number of other Tokens.
 *   Another way of using the AllowList is to use a specific list for a specific token, e.g. allowListA for tokenA managed by companyA. This way, companyA can
 *   independently decide which addresses to add to their allowListA, granting them the power to control who can use their tokenA.
 */
contract AllowList is Ownable2StepUpgradeable, ERC2771ContextUpgradeable {
    /**
     * @notice Stores the attributes for each address.
     * @dev Attributes are defined as bit mask, with the bit position encoding it's meaning and the bit's value whether this attribute is attested or not.
     *    Example:
     *    - position 0: 1 = has been KYCed (0 = not KYCed)
     *    - position 1: 1 = is american citizen (0 = not american citizen)
     *    - position 2: 1 = is a penguin (0 = not a penguin)
     *    These meanings are not defined within code, neither in the token contract nor the allowList. Nevertheless, the definition used by the people responsible for both contracts MUST match,
     *    or the token contract will not work as expected. E.g. if the allowList defines position 2 as "is a penguin", while the token contract uses position 2 as "is a hedgehog", then the tokens
     *    might be sold to hedgehogs, which was never the intention.
     *    Here some examples of how requirements can be used in practice:
     *    value 0b0000000000000000000000000000000000000000000000000000000000000101, means "is KYCed and is a penguin"
     *    value 0b0000000000000000000000000000000000000000000000000000000000000111, means "is KYCed, is american and is a penguin"
     *    value 0b0000000000000000000000000000000000000000000000000000000000000000, means "has not proven any relevant attributes to the allowList operator" (default value)
     *
     *    The highest four bits are defined as tiers as follows (depicted with less bits because 256 is a lot):
     *    - 0b0000000000000000000000000000000000000000000000000000000000000000 = tier 0
     *    - 0b0001000000000000000000000000000000000000000000000000000000000000 = tier 1
     *    - 0b0011000000000000000000000000000000000000000000000000000000000000 = tier 2 (and 1)
     *    - 0b0111000000000000000000000000000000000000000000000000000000000000 = tier 3 (and 2 and 1)
     *    - 0b1111000000000000000000000000000000000000000000000000000000000000 = tier 4 (and 3 and 2 and 1)
     *    This very simple definition allows for a maximum of 5 tiers, even though 4 bits are used for encoding. By sacrificing some space it can be implemented without code changes.
     */
    mapping(address => uint256) public map;

    /**
     * @notice Attributes for `key` have been set to `value`
     * @param _addr address the attributes are set for
     * @param _attributes new attributes
     */
    event Set(address indexed _addr, uint256 _attributes);

    /**
     * @notice Creates a new AllowList contract without owner that be used for cloning.
     * @param _trustedForwarder the trusted forwarder (ERC2771) can not be changed, but is checked for security
     */
    constructor(address _trustedForwarder) ERC2771ContextUpgradeable(_trustedForwarder) {
        _disableInitializers();
    }

    /**
     * Initializes a new AllowList clone.
     * @param _owner the owner of the contract
     */
    function initialize(address _owner) public initializer {
        require(_owner != address(0), "owner can not be zero address");
        _transferOwnership(_owner);
    }

    /**
     * @notice sets (or updates) the attributes for an address
     * @param _addr address to be set
     * @param _attributes new attributes
     */
    function set(address _addr, uint256 _attributes) external onlyOwner {
        map[_addr] = _attributes;
        emit Set(_addr, _attributes);
    }

    /**
     * @notice purges an address from the allowList
     * @dev this is a convenience function, it is equivalent to calling set(_addr, 0)
     * @param _addr address to be removed
     */
    function remove(address _addr) external onlyOwner {
        delete map[_addr];
        emit Set(_addr, 0);
    }

    /**
     * @dev both Ownable and ERC2771Context have a _msgSender() function, so we need to override and select which one to use.
     */
    function _msgSender() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (address) {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /**
     * @dev both Ownable and ERC2771Context have a _msgData() function, so we need to override and select which one to use.
     */
    function _msgData() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (bytes calldata) {
        return ERC2771ContextUpgradeable._msgData();
    }
}
