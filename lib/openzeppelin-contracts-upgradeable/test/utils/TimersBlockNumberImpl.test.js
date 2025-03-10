const { BN, time } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const TimersBlockNumberImpl = artifacts.require('TimersBlockNumberImpl');

contract('TimersBlockNumber', function () {
  beforeEach(async function () {
    this.instance = await TimersBlockNumberImpl.new();
    this.now = await web3.eth.getBlock('latest').then(({ number }) => number);
  });

  it('unset', async function () {
    expect(await this.instance.getDeadline()).to.be.bignumber.equal('0');
    expect(await this.instance.isUnset()).to.be.equal(true);
    expect(await this.instance.isStarted()).to.be.equal(false);
    expect(await this.instance.isPending()).to.be.equal(false);
    expect(await this.instance.isExpired()).to.be.equal(false);
  });

  it('pending', async function () {
    await this.instance.setDeadline(this.now + 3);
    expect(await this.instance.getDeadline()).to.be.bignumber.equal(new BN(this.now + 3));
    expect(await this.instance.isUnset()).to.be.equal(false);
    expect(await this.instance.isStarted()).to.be.equal(true);
    expect(await this.instance.isPending()).to.be.equal(true);
    expect(await this.instance.isExpired()).to.be.equal(false);
  });

  it('expired', async function () {
    await this.instance.setDeadline(this.now - 3);
    expect(await this.instance.getDeadline()).to.be.bignumber.equal(new BN(this.now - 3));
    expect(await this.instance.isUnset()).to.be.equal(false);
    expect(await this.instance.isStarted()).to.be.equal(true);
    expect(await this.instance.isPending()).to.be.equal(false);
    expect(await this.instance.isExpired()).to.be.equal(true);
  });

  it('reset', async function () {
    await this.instance.reset();
    expect(await this.instance.getDeadline()).to.be.bignumber.equal(new BN(0));
    expect(await this.instance.isUnset()).to.be.equal(true);
    expect(await this.instance.isStarted()).to.be.equal(false);
    expect(await this.instance.isPending()).to.be.equal(false);
    expect(await this.instance.isExpired()).to.be.equal(false);
  });

  it('fast forward', async function () {
    await this.instance.setDeadline(this.now + 3);
    expect(await this.instance.isPending()).to.be.equal(true);
    expect(await this.instance.isExpired()).to.be.equal(false);
    await time.advanceBlockTo(this.now + 3);
    expect(await this.instance.isPending()).to.be.equal(false);
    expect(await this.instance.isExpired()).to.be.equal(true);
  });
});
