.. _custodian:

#########
Custodian
#########

Custodian contracts allow approved entities to hold tokens on behalf of multiple investors. Common examples of custodians include broker/dealers and secondary markets.

Custodians interact with an issuer’s investor counts differently from regular investors. When an investor transfers a balance into a custodian it does not increase the overall investor count, instead the investor is now included in the list of beneficial owners represented by the custodian. Even if the investor now has a balance of 0, they will be still be included in the issuer’s investor count.

Custodian contracts include the standard SFT protocol :ref:`multisig` and :ref:`modules` functionality. See the respective documents for detailed information on these components.

This documentation only explains contract methods that are meant to be accessed directly. External methods that will revert unless called through another contract, such as IssuingEntity or modules, are not included.

It may be useful to view the `Custodian.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/Custodian.sol>`__ source code while reading this document.

Deployment
==========

The constructor declares the owner as per standard :ref:`multisig`.

.. method:: Custodian.constructor(address[] _owners, uint32 _threshold)

    * ``_owners``: One or more addresses to associate with the contract owner. The address deploying the contract is not implicitly included within the owner list.
    * ``_threshold``: The number of calls required for the owner to perform a multi-sig action.

    The ID of the owner is generated as a keccak of the contract address and available from the public getter ``ownerID``.

Token Transfers
===============

To maintain accurate beneficial owner records, custodians must initiate all token transfers through the contract instead of calling ``SecurityToken.transfer`` directly.

.. method:: Custodian.transfer(address _token, address _to, uint256 _value, bool _stillOwner)

    Transfers tokens from the custodian.

    * ``_token``: Contract address of the token to transfer
    * ``_to``: Address of the recipient
    * ``_value``: Number of tokens to transfer
    * ``_stillOwner``: After this transfer, is the recipient still on the custodian's list of beneficial owners for this token?

    The ``_stillOwner`` boolean is only used to remove investors from the list of beneficial owners. If it is set to true but the recipient was not previously listed, they will not be added.

Ether Transfers
===============

There may be cases where a custodian will need receive ether into their contract, and distribute it to one or more investors. The contract includes a fallback function allowing anyone to send ether in. Approved custodian authorities may transfer tokens out via the following function:

.. method:: Custodian.transferEther(address[] _to, uint256[] _value)

    Transfers ether from of the custodian contract.

    * ``_to``: Array of address to transfer to.
    * ``_value``: Array of amounts to transfer.

    The function will iterate over both arrays, sending ``amount[0]`` ether to ``to[0]`` and so on.


Beneficial Owners
=================

Whenever a token transfer happens on-chain, the custodian's beneficial owner list is updated:

    * When tokens are transfered to a custodian, the sender is added to the list of beneficial owners for that token.
    * When tokens are transfered from a custodian, the receipient may be removed from the list of beneficial owners by setting ``_stillOwner`` to false.

As one of the purposes of custodians is to facilitate off-chain transfers of ownership, they are also able to manually update their beneficial ownership records.

.. warning:: When adding a beneficial owner no checks are made against country restrictions, investor limits, or minimum investor ratings. It is the responsibility of the custodian to ensure compliance in any off-chain transfers of ownership.

.. method:: Custodian.addInvestors(address _token, bytes32[] _id)

    Adds beneficial owners to a token.

    * ``_token``: Contract address of the token to add benefical owners to.
    * ``_id``: Array of investor IDs.

    Calling this method with an investor ID that is already a beneficial owner will not cause it to throw.

.. method:: Custodian.removeInvestors(address _token, bytes32[] _id)

    Removes beneficial owners from a token.

    * ``_token``: Contract address of the token to remove benefical owners from.
    * ``_id``: Array of investor IDs.

    Calling this method with an investor ID that is not a beneficial owner will not cause it to throw.

.. _custodian-modules:

Modules
=======

See the :ref:`modules` documentation for information module funtionality and development.

.. method:: Custodian.attachModule(address _module)

    Attaches a module to the custodian.

.. method:: Custodian.detachModule(address _module)

    Detaches a module. A module may call to detach itself, but not other modules.

.. method:: Custodian.isActiveModule(address _module)

     Returns true if a module is currently active on the contract.

