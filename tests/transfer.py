#!/usr/bin/python3

import time

DEPLOYMENT = "simple"

def transfer_from_issuer():
    '''Transfers from issuer to investors''' 
    global issuer, token, a
    issuer = IssuingEntity[0]
    token = SecurityToken[0]
    a = accounts
    check.confirms(token.transfer, (a[2], 100), "Unable to send to account 2")
    check.equal(token.balanceOf(a[2]), 100, "Wrong balance on account 2")
    check.confirms(token.transfer,(a[3], 1000), "Unable to send to account 3")
    check.equal(token.balanceOf(a[3]), 1000, "Wrong balance on account 3")
    check.confirms(token.transfer, (a[4], 100), "Unable to send to account 4")
    check.confirms(token.transfer, (a[4], 100), "Unable to send to account 4")
    check.equal(token.balanceOf(a[4]), 200, "Wrong balance on account 4")
    check.equal(token.balanceOf(a[1]), 0, "Wrong balance on account 1")
    check.equal(token.balanceOf(issuer.address), 998700, "Wrong balance on issuer")
    
def transfer_between_investors():
    '''Transfers between investors'''
    check.confirms(token.transfer, (a[4], 100, {'from':a[2]}), "Unable to send to account 4")
    check.equal(token.balanceOf(a[4]), 300, "Wrong balance on account 4")
    check.equal(token.balanceOf(a[2]), 0, "Wrong balance on account 2")
    check.confirms(token.transfer, (a[5], 500, {'from':a[3]}), "Unable to send to account 3")
    check.equal(token.balanceOf(a[3]), 500, "Wrong balance on account 3")
    check.equal(token.balanceOf(a[5]), 500, "Wrong balance on account 5")

def transfer_from():
    '''Approve and TransferFrom'''
    check.confirms(token.transferFrom,(a[5],a[3],100), "Issuer cannot transferFrom")
    check.equal(token.balanceOf(a[3]), 600, "Wrong balance on account 3")
    check.equal(token.balanceOf(a[5]), 400, "Wrong balance on account 5")
    check.reverts(token.transferFrom,(a[5],a[3],100, {'from':a[4]}), "Account 4 can transferFrom without approval")
    check.confirms(token.approve,(a[4],100,{'from':a[5]}), "approve reverted")
    check.reverts(token.transferFrom,(a[5],a[3],200, {'from':a[4]}), "Account 4 can transferFrom exceeding approved amount")
    check.confirms(token.transferFrom,(a[5],a[3],50, {'from':a[4]}), "Account 4 cannot transferFrom")
    check.equal(token.allowance(a[5],a[4]), 50, "Allowed is wrong")

def transfer_same_investor():
    '''Transfers from multiple addresses with same ID'''
    check.confirms(KYCRegistrar[0].addInvestor,(b"investor8", 1, b'abc', 1, 9999999999, a[8:10]),"Could not add investor to registrar")
    check.confirms(token.transfer,(a[8],1000), "Unable to send to account 8")
    check.equal(token.balanceOf(a[8]),1000, "Account 8 balance wrong")
    check.equal(token.balanceOf(a[9]),0, "Account 9 balance wrong")
    check.confirms(token.transfer,(a[9],500, {'from':a[8]}), "Unable to send to account 9")
    check.equal(token.balanceOf(a[8]),500, "Account 8 balance wrong")
    check.equal(token.balanceOf(a[9]),500, "Account 9 balance wrong")
    check.confirms(token.transferFrom,(a[8],a[3],400,{'from':a[9]}), "Could not transferFrom")
    check.equal(token.balanceOf(a[3]), 1050, "Wrong balance on account 3")
    check.equal(token.balanceOf(a[8]),100, "Account 8 balance wrong")
    check.equal(token.balanceOf(a[9]),500, "Account 9 balance wrong")
    