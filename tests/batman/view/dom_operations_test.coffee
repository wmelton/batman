helpers = if typeof require is 'undefined' then window.viewHelpers else require './view_helper'

QUnit.module "Batman.DOM helpers"
  setup: ->
    class @TestView extends Batman.View
      constructor: ->
        @constructor.instance = @
        super

    @context = Batman
      OuterView: class OuterView extends @TestView
      InnerView: class InnerView extends @TestView

    @simpleSource = '<div class="outer" data-view="OuterView"><div><p class="inner" data-view="InnerView"></p></div></div>'
  teardown: ->
    Batman.DOM.Yield.reset()

asyncTest "setInnerHTML fires beforeDisappear and disappear events on views about to be removed", 4, ->
  helpers.render @simpleSource, false, @context, (node) =>
    @context.OuterView.instance.on 'beforeDisappear', -> ok @get('node').parentNode
    @context.OuterView.instance.on 'disappear',       -> ok !@get('node').parentNode
    @context.InnerView.instance.on 'beforeDisappear', -> ok @get('node').parentNode
    @context.InnerView.instance.on 'disappear',       -> ok @get('node').parentNode

    Batman.DOM.setInnerHTML(node, "")
    QUnit.start()

asyncTest "removeNode fires beforeDisappear and disappear events on views about to be removed", 4, ->
  helpers.render @simpleSource, false, @context, (node) =>
    @context.OuterView.instance.on 'beforeDisappear', -> ok @get('node').parentNode
    @context.OuterView.instance.on 'disappear',       -> ok !@get('node').parentNode
    @context.InnerView.instance.on 'beforeDisappear', -> ok @get('node').parentNode
    @context.InnerView.instance.on 'disappear',       -> ok @get('node').parentNode

    Batman.DOM.removeNode(node.childNodes[0])
    QUnit.start()

asyncTest "destroyNode fires beforeDisappear, beforeDestroy, disappear, and destroy events on views about to be removed", 8, ->
  helpers.render @simpleSource, false, @context, (node) =>
    @context.OuterView.instance.on 'beforeDisappear', -> ok true
    @context.OuterView.instance.on 'beforeDestroy',   -> ok true
    @context.OuterView.instance.on 'disappear',       -> ok !@get('node').parentNode
    @context.OuterView.instance.on 'destroy',         -> ok !@get('node').parentNode
    @context.InnerView.instance.on 'beforeDisappear', -> ok true
    @context.InnerView.instance.on 'beforeDestroy',   -> ok true
    @context.InnerView.instance.on 'disappear',       -> ok true
    @context.InnerView.instance.on 'destroy',         -> ok true

    Batman.DOM.destroyNode(node.childNodes[0])
    QUnit.start()

asyncTest "destroyNode fires calls die on views about to be removed", 1, ->
  helpers.render @simpleSource, false, @context, (node) =>
    view = Batman._data node, 'view'
    view.die = spy = createSpy()
    Batman.DOM.destroyNode(node)
    ok spy.called
    QUnit.start()

asyncTest "appendChild fires beforeAppear and appear events on views being added", 4, ->
  helpers.render @simpleSource, false, @context, (node) =>
    newElement = $('<div/>')[0]

    @context.OuterView.instance.on 'beforeAppear', -> ok true
    @context.OuterView.instance.on 'appear',       -> equal @get('node').parentNode, newElement
    @context.InnerView.instance.on 'beforeAppear', -> ok @get('node').parentNode
    @context.InnerView.instance.on 'appear',       -> ok @get('node').parentNode

    Batman.DOM.appendChild newElement, @context.OuterView.instance.get('node')
    QUnit.start()

asyncTest "insertBefore fires beforeAppear and appear events on views being added", 4, ->
  helpers.render @simpleSource, false, @context, (node) =>
    newElement = $('<div/>')[0]

    @context.OuterView.instance.on 'beforeAppear', -> ok true
    @context.OuterView.instance.on 'appear',       -> equal @get('node').parentNode, newElement
    @context.InnerView.instance.on 'beforeAppear', -> ok @get('node').parentNode
    @context.InnerView.instance.on 'appear',       -> ok @get('node').parentNode

    Batman.DOM.insertBefore newElement, @context.OuterView.instance.get('node')
    QUnit.start()

asyncTest "removeOrDestroyNode removes but does not destroy cached views", 1, ->
  @context.OuterView::cached = true
  failNow = true
  helpers.render @simpleSource, false, @context, (node) =>
    ok @context.OuterView.instance.get('cached')
    @context.OuterView.instance.on 'destroy', -> ok false if failNow
    Batman.DOM.removeOrDestroyNode(node.childNodes[0])
    failNow = false
    QUnit.start()

asyncTest "removeOrDestroyNode destroys non-cached views", 2, ->
  helpers.render @simpleSource, false, @context, (node) =>
    @context.OuterView.instance.on 'destroy', -> ok true
    @context.InnerView.instance.on 'destroy', -> ok true
    Batman.DOM.removeOrDestroyNode(node.childNodes[0])
    QUnit.start()

asyncTest "removeOrDestroyNode removes yielded nodes when their parents are removed (because they are cached)", 1, ->
  source = """
    <div class="foo" data-yield="foo"></div>
    <div class="cached" data-view="CachedView">
      <div data-contentfor="foo">
        <div data-view="InnerView">cached content</div>
      </div>
    </div>
  """

  @context.CachedView = class CachedView extends @TestView
    cached: true

  failNow = true
  helpers.render source, false, @context, (node) =>
    @context.CachedView.instance.on 'destroy', -> ok false if failNow
    @context.InnerView.instance.on  'destroy', -> ok false if failNow
    Batman.DOM.removeOrDestroyNode($('.cached', node)[0])

    equal $('.foo', node).html(), ""
    failNow = false
    QUnit.start()

asyncTest "removeOrDestroyNode removes yielded nodes when the yield is cleared if the yielded node's parent is cached", 1, ->
  source = """
    <div class="foo" data-yield="foo"></div>
    <div class="cached" data-view="CachedView">
      <div data-contentfor="foo">
        <div data-view="InnerView">cached content</div>
      </div>
    </div>
  """
  @context.CachedView = class CachedView extends @TestView
    cached: true

  failNow = true
  helpers.render source, false, @context, (node) =>
    @context.CachedView.instance.on 'destroy', -> ok false if failNow
    @context.InnerView.instance.on  'destroy', -> ok false if failNow
    @context.InnerView.instance.on  'disappear', -> ok true
    Batman.DOM.Yield.withName('foo').clear()
    failNow = false
    QUnit.start()

asyncTest "removeOrDestroyNode destroys yielded nodes when the yield is cleared if the yielded node's parent is not cached", 1, ->
  source = """
    <div class="bar" data-yield="bar"></div>
    <div class="notcached" data-view="OuterView">
      <div data-contentfor="bar">
        <div data-view="InnerView">
          uncached content
        </div>
      </div>
    </div>
  """
  failNow = true
  helpers.render source, false, @context, (node) =>
    @context.InnerView.instance.on  'destroy', -> ok true
    @context.OuterView.instance.on  'destroy', -> ok false if failNow
    Batman.DOM.Yield.withName('bar').clear()
    failNow = false
    QUnit.start()

test "addEventListener and removeEventListener store and remove callbacks using Batman.data", ->
  div = document.createElement 'div'
  f = ->

  Batman.DOM.addEventListener div, 'click', f
  listeners = Batman._data div, 'listeners'
  ok ~listeners.click.indexOf f

  Batman.DOM.removeEventListener div, 'click', f
  listeners = Batman._data div, 'listeners'
  ok !~listeners.click.indexOf f

asyncTest "destroyNode: destroys yielded childNodes when their parents are destroyed", 2, ->
  source = """
    <div class="bar" data-yield="bar"></div>
    <div class="notcached" data-view="OuterView">
      <div data-contentfor="bar">
        <div data-view="InnerView">
          uncached content
        </div>
      </div>
    </div>
  """
  helpers.render source, false, @context, (node) =>
    @context.OuterView.instance.on 'destroy', -> ok true
    @context.InnerView.instance.on  'destroy', -> ok true
    Batman.DOM.destroyNode($('.notcached', node)[0])

    equal $('.bar', node).html(), ""

    QUnit.start()

asyncTest "destroyNode: destroys nodes inside a yield when the yield is destroyed", 1, ->
  source = """
    <div class="bar" data-yield="bar"></div>
    <div class="notcached" data-view="OuterView">
      <div data-contentfor="bar">
        <div data-view="InnerView">
          uncached content
        </div>
      </div>
    </div>
  """

  helpers.render source, false, @context, (node) =>
    @context.InnerView.instance.on 'destroy', -> ok true
    Batman.DOM.destroyNode($('.bar', node)[0])
    QUnit.start()

asyncTest "destroyNode: bindings are kept in Batman.data and destroyed when the node is removed", 6, ->
  context = new Batman.Object bar: true
  context.accessor 'foo', (spy = createSpy -> @get('bar'))
  helpers.render '<div data-addclass-foo="foo"><div data-addclass-foo="foo"></div></div>', context, (node) ->
    ok spy.called

    parent = node[0]
    child = parent.childNodes[0]
    for node in [child, parent]
      bindings = Batman._data node, 'bindings'
      ok bindings.length > 0

      Batman.DOM.destroyNode node
      deepEqual Batman._data(node), {}

    context.set('bar', false)
    equal spy.callCount, 1
    QUnit.start()

asyncTest "destroyNode: iterators are kept in Batman.data and destroyed when the parent node is removed", 5, ->
  context = new Batman.Object bar: 'baz'
  set = null
  context.accessor 'foo', (setSpy = createSpy -> set = new Batman.Set @get('bar'), 'qux')
  helpers.render '<div id="parent"><div data-foreach-x="foo" data-bind="x"></div></div>', context, (node) ->
    equal setSpy.callCount, 1  # Cached, so only called once

    parent = node[0]
    toArraySpy = spyOn(set, 'toArray')

    Batman.DOM.destroyNode(parent)
    deepEqual Batman._data(parent), {}

    context.set('bar', false)
    equal setSpy.callCount, 1

    equal toArraySpy.callCount, 0
    set.fire('change')
    equal toArraySpy.callCount, 0
    QUnit.start()

asyncTest "destroyNode: Batman.DOM.Style objects are kept in Batman.data and destroyed when their node is removed", ->
  context = Batman
    styles: new Batman.Hash(color: 'green')

  styles = null
  context.accessor 'css', (setSpy = createSpy -> styles = @styles)
  helpers.render '<div data-bind-style="css"></div>', context, (node) ->
    equal setSpy.callCount, 1  # Cached, so only called once

    node = node[0]
    itemsAddedSpy = spyOn(context.get('styles'), 'itemsWereAdded')

    Batman.DOM.destroyNode(node)
    deepEqual Batman._data(node), {}

    context.set('styles', false)
    equal setSpy.callCount, 1

    equal itemsAddedSpy.callCount, 0
    styles.fire('itemsWereAdded')
    equal itemsAddedSpy.callCount, 0
    QUnit.start()

asyncTest "destroyNode: listeners are kept in Batman.data and destroyed when the node is removed", 8, ->
  context = new Batman.Object foo: ->

  helpers.render '<div data-event-click="foo"><div data-event-click="foo"></div></div>', context, (node) ->
    parent = node[0]
    child = parent.childNodes[0]
    for n in [child, parent]
      listeners = Batman._data n, 'listeners'
      ok listeners.click.length > 0

      if Batman.DOM.hasAddEventListener
        spy = spyOn n, 'removeEventListener'
      else
        # Spoof detachEvent because typeof detachEvent is 'object' in IE8, and
        # spies break because detachEvent.call blows up
        n.detachEvent = ->
        spy = spyOn n, 'detachEvent'

      Batman.DOM.destroyNode n

      ok spy.called
      deepEqual Batman.data(n), {}
      deepEqual Batman._data(n), {}

    QUnit.start()

asyncTest "removeNode: nodes with views are not unbound if they are cached", ->
  context = Batman
    bar: "foo"
    TestView: class TestView extends Batman.View
      cached: true

  helpers.render '<div data-view="TestView"><span data-bind="bar"></span></div>', context, (node) ->
    equal node.find('span').html(), "foo"
    Batman.DOM.removeNode node[0]
    context.set 'bar', 'baz'
    equal node.find('span').html(), "baz"
    QUnit.start()

asyncTest "removeNode: cached view can be reinserted", ->
  context = Batman
    bar: "foo"
    TestView: @TestView

  helpers.render '<div data-view="TestView"><span data-bind="bar"></span></div>', context, (node) ->
    equal node.find('span').html(), "foo"
    Batman.DOM.removeNode(node[0])

    newElement = $('<div/>')[0]
    Batman.DOM.appendChild newElement, context.TestView.instance.get('node')
    equal $(newElement).find('span').html(), "foo"
    context.set 'bar', 'baz'
    equal $(newElement).find('span').html(), "baz"
    QUnit.start()

asyncTest "removeNode: cached views with inner views can be reinserted", ->

  innerAppearSpy = createSpy()
  innerDisappearSpy = createSpy()

  context = Batman
    bar: "foo"
    OuterView: class OuterView extends @TestView
      cached: true
    InnerView: class InnerView extends @TestView
      constructor: ->
        super
        @on 'appear', innerAppearSpy
        @on 'disappear', innerDisappearSpy

  helpers.render '<div data-view="OuterView"><div data-view="InnerView"><span data-bind="bar"></span></div></div>', context, (node) ->
    equal node.find('span').html(), "foo"
    equal innerAppearSpy.callCount, 1
    equal innerDisappearSpy.callCount, 0

    Batman.DOM.removeNode(node[0])
    equal innerDisappearSpy.callCount, 1

    newElement = $('<div/>')[0]
    Batman.DOM.appendChild newElement, context.OuterView.instance.get('node')
    equal innerAppearSpy.callCount, 2

    equal $(newElement).find('span').html(), "foo"
    context.set 'bar', 'baz'
    equal $(newElement).find('span').html(), "baz"
    QUnit.start()

asyncTest "bindings added underneath other bindings notify their parents", ->
  context = Batman
    foo: "foo"
    bar: "bar"

  class TestBinding extends Batman.DOM.AbstractBinding
    @instances = []
    constructor: ->
      @childBindingAdded = createSpy()
      super
      @constructor.instances.push @

  Batman.DOM.readers.test = -> new TestBinding(arguments...)
  source = '''
    <div data-test="true">
      <div data-test="true">
        <p data-bind="foo"></p>
        <p data-bind="bar"></p>
      </div>
    </div>
  '''

  helpers.render source, context, (node, view) ->
    equal TestBinding.instances.length, 2
    equal TestBinding.instances[0].childBindingAdded.callCount, 3
    calls = TestBinding.instances[0].childBindingAdded.calls
    ok calls[0].arguments[0] instanceof TestBinding
    ok calls[1].arguments[0] instanceof Batman.DOM.AbstractBinding
    ok calls[1].arguments[0].get('filteredValue'), 'foo'
    ok calls[2].arguments[0] instanceof Batman.DOM.AbstractBinding
    ok calls[2].arguments[0].get('filteredValue'), 'bar'

    equal TestBinding.instances[1].childBindingAdded.callCount, 2
    calls = TestBinding.instances[1].childBindingAdded.calls
    ok calls[0].arguments[0] instanceof Batman.DOM.AbstractBinding
    ok calls[0].arguments[0].get('filteredValue'), 'foo'
    ok calls[1].arguments[0] instanceof Batman.DOM.AbstractBinding
    ok calls[1].arguments[0].get('filteredValue'), 'bar'
    QUnit.start()
