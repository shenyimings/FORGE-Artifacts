// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IZNSPricer } from "../types/IZNSPricer.sol";


/**
 * @title IDistributionConfig.sol - An interface containing all types required for
 * distribution configuration of a domain.
 * @dev Types outlined in this config are stored on the `ZNSSubRegistrar` contract and are used to determine
 * how subdomains are distributed for each parent domain.
 * Below are docs for the types in this file:
 *  - `DistributionConfig`: Struct containing the configuration data for a parent domain:
 *      + `pricerContract`: The address of the pricer contract chosen by the owner of the
 *          parent domain (IZNSPricer type required!)
 *      + `paymentType`: The payment type chosen by the owner of the parent domain
 *      + `accessType`: The access type chosen by the owner of the parent domain
 *  - `AccessType`: Enum signifying the access type of a parent domain:
 *      + `LOCKED`: The parent domain is locked which mean no subdomains can be registered
 *      + `OPEN`: The parent domain is open which means anyone can register a subdomain
 *      + `MINTLIST`: The parent domain has to approve each individual address for registering a subdomain
 *  - `PaymentType`: Enum signifying the payment type for a parent domain:
 *      + `DIRECT`: The subdomains are paid for directly by the user to the beneficiary chosen by the owner
 *      + `STAKE`: The subdomains are paid for by staking an amount of token chosen by the owner to ZNSTreasury
*/
interface IDistributionConfig {

    enum AccessType {
        LOCKED,
        OPEN,
        MINTLIST
    }

    enum PaymentType {
        DIRECT,
        STAKE
    }

    struct DistributionConfig {
        IZNSPricer pricerContract;
        PaymentType paymentType;
        AccessType accessType;
    }
}
