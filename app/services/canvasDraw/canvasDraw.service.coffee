'use strict'

#===============================================================================
#
#	Canvas Draw Service
# 		Helper service to drawing shapes + animations on the canvas
#
#-------------------------------------------------------------------------------

$requires = [
	'$log'
	'$interval'
	'SHAPE'
	'HEXCOLORS'
	require '../../services/utils'
]

canvasDrawService = ( $log, $interval, SHAPE, HEXCOLORS, utils ) ->
	class CanvasDrawService
		#	@constructor
		#-------------------------------------------------------------------
		constructor: ( ctx, opts ) ->
			@_defaults =
				# Radius for the rounded cornders
				radius: 3
				# Size of the shape
				size: SHAPE.SIZE

			@opts = angular.extend({}, @_defaults, opts)

			# Shortcuts to the options
			@radius = @opts.radius
			@defaultSize = @opts.size

			# Canvas context
			@ctx = ctx

			return

		#	@clear
		# 		Clear only a part of the canvas
		#-------------------------------------------------------------------
		clear: (x, y, width, height) =>
			# If an object has been passed split it into the individual vars
			if angular.isObject( x )
				opts = angular.extend({}, {}, x)
				x = opts.x
				y = opts.y
				width = opts.width
				height = opts.height

			@ctx.clearRect(x, y, width, height)

		#	@create
		# 		Helper service to draw a shape
		# 		Calls the correct draw function based on the params, and
		# 		styles and colors the shape
		#-------------------------------------------------------------------
		create: ( params ) ->
			_defaults =
				type: 'square'
				color: 'white'
				coords: {x: 0, y: 0}
				size: {w: @defaultSize, h: @defaultSize}
				style: 'untouched'

			params = angular.extend({}, _defaults, params)

			# Convert the text color to the hex version
			if params.color.indexOf('#') < 0
				params.color = HEXCOLORS[params.color]

			# $log.debug( params )

			# Do we need to clear a space?
			if params.clear?
				@clear( params.clear )

			# Get the shape function based on the type of shape we want
			makeShape = @[params.type]

			# Draw the shape on the canvas
			makeShape?(params.coords.x, params.coords.y, params.size.w, params.size.h)

			# Set the style of the shape
			@setShapeStyle( params )

			return

		#	@createDrawParams
		# 		utility for converting a node to the correct params
		#---------------------------------------------------------------
		createDrawParams: ( node, nodeStyle, clearStyle ) ->
			return if !node?

			if clearStyle? and clearStyle == 'small'
				clear =
					x: node.position.x
					y: node.position.y
					width: SHAPE.SIZE
					height: SHAPE.SIZE
			else if clearStyle? and clearStyle == 'large'
				clear =
					x: node.position.x - SHAPE.MARGIN
					y: node.position.y - SHAPE.MARGIN
					width: SHAPE.OUTERSIZE + SHAPE.MARGIN
					height: SHAPE.OUTERSIZE + SHAPE.MARGIN
			else
				clear =
					x: node.position.x - (SHAPE.MARGIN / 2)
					y: node.position.y - (SHAPE.MARGIN / 2)
					width: SHAPE.OUTERSIZE
					height: SHAPE.OUTERSIZE

			return {
				type: node.type
				color: node.color
				style: nodeStyle
				coords: {x: node.position.x, y: node.position.y}
				clear: clear
			}

		#	@runAnimation
		# 		Helper service to animate a shape
		# 		Calls the correct animation function based on the params, and
		# 		styles and colors the shape
		#-------------------------------------------------------------------
		runAnimation: ( params, callbacks ) =>
			_defaults =
				type: 'square'
				color: 'white'
				coords: {x: 0, y: 0}
				size: {w: @defaultSize, h: @defaultSize}
				style: 'untouched'
				duration: 300

			params = angular.extend({}, _defaults, params)

			# Convert the text color to the hex version
			params.color = HEXCOLORS[params.color]

			# Calculate/get the start and end times of the animation
			enterStart = new Date().getTime()
			enterEnd = enterStart + params.duration
			leaveEnd = enterStart + (params.duration * 2)

			# Create the animation loop
			enterAnimation = () =>
				# Get our current progres
				timestamp = new Date().getTime()
				progress = Math.min((params.duration - (enterEnd - timestamp)) / params.duration, 1)

				animationType = params.animation.type
				animationFunc = null

				if animationType is 'shadow'
					animationFunc = @shadowAnimation

				else if animationType is 'glow'
					animationFunc = @glowEnterAnimation

				else if animationType is 'fill'
					animationFunc = @fillAnimation

				else if animationType is 'fadeOut'
					animationFunc = @fadeOutAnimation

				else if animationType is 'shake'
					animationFunc = @shakeAnimation

				shape = animationFunc?( params, progress, callbacks?.during)

				# If the animation hasn't finished, repeat the animation loop
				if (progress < 1)
					callbacks.before?( animation, shape )

					animation = requestAnimationFrame(enterAnimation)

					callbacks.running?( animation, shape )

					callbacks.after?( animation, shape )
				else
					if animationType is 'glow'
						leaveAnimation()
					else
						callbacks.done?(shape)

			leaveAnimation = () =>
				# Get our current progres
				timestamp = new Date().getTime()
				progress = Math.min((params.duration - (leaveEnd - timestamp)) / params.duration, 1)
				animationType = params.animation.type

				if animationType is 'glow'
					shape = @glowLeaveAnimation( params, progress, callbacks?.during )

				# If the animation hasn't finished, repeat the animation loop
				if (progress < 1)
					callbacks.before?( animation, shape )

					animation = requestAnimationFrame(leaveAnimation)

					callbacks.running?( animation, shape )

					callbacks.after?( animation, shape )
				else
					callbacks.done?(shape)


			# Start the animation
			return enterAnimation()

		#	@stopAnimation
		# 		Cancel the passed animation
		#-------------------------------------------------------------------
		stopAnimation: ( animation ) ->
			window.cancelAnimationFrame(animation)
			animation = undefined

		#	@setShapeStyle
		# 		Styles the shape based on it's status
		#-------------------------------------------------------------------
		setShapeStyle: ( params ) ->
			@ctx.save()
			@ctx.lineWidth = SHAPE.BORDER

			rgb = utils.hexToRgb(params.color)

			# Untouched: solid filled shape
			if params.style is 'untouched'
				@ctx.fillStyle = "rgba(#{rgb.r}, #{rgb.g}, #{rgb.b}, 1)"
				@ctx.strokeStyle = params.color
				@ctx.shadowColor = 'rgba(0,0,0,0.0)'
				@ctx.shadowBlur = 0
				@ctx.shadowOffsetX = 0
				@ctx.shadowOffsetY = 0

			# Start: White outline filled shape
			else if params.style is 'start'
				@ctx.fillStyle = "rgba(#{rgb.r}, #{rgb.g}, #{rgb.b}, 1)"
				@ctx.strokeStyle = 'rgba(255,255,255,0.8)'

			# Touched: Colored outlined shape (no fill)
			else if params.style is 'touched'
				@ctx.fillStyle = 'rgba(0,0,0,0.0)'
				@ctx.strokeStyle = params.color

			# Touched: black outline filled shape
			else if params.style is 'disallowed'
				@ctx.fillStyle = "rgba(#{rgb.r}, #{rgb.g}, #{rgb.b}, 0.9)"
				@ctx.strokeStyle = 'black'

			# Touched: faded filled shape
			else if params.style is 'faded'
				@ctx.fillStyle = "rgba(#{rgb.r}, #{rgb.g}, #{rgb.b}, 0.2)"
				@ctx.strokeStyle = 'rgba(0,0,0,0.0)'
				@ctx.shadowColor = 'rgba(0,0,0,0.0)'
				@ctx.shadowBlur = 0
				@ctx.shadowOffsetX = 0
				@ctx.shadowOffsetY = 0

			else if params.style is 'glow'
				@ctx.fillStyle = "rgba(#{rgb.r}, #{rgb.g}, #{rgb.b}, 0.4)"
				@ctx.strokeStyle = "rgba(#{rgb.r}, #{rgb.g}, #{rgb.b}, 1.0)"
				@ctx.shadowColor = "rgba(#{rgb.r}, #{rgb.g}, #{rgb.b}, 0.9)"
				@ctx.shadowBlur = 30
				@ctx.shadowOffsetX = 0
				@ctx.shadowOffsetY = 0

			@ctx.fill()
			@ctx.stroke()
			@ctx.restore()

		#	@glowEnterAnimation
		# 		Creates a glow around the shape
		#-------------------------------------------------------------------
		glowEnterAnimation: (params, progress, cb) =>
			# $log.debug('in enter animation')
			# Shape width/height grows outward
			shape =
				width: (params.size.w * progress) * 3.2
				height: (params.size.h * progress) * 3.2

				# width: params.size.w + ((params.size.w * progress) * 2.5)
				# height: params.size.h + ((params.size.h * progress) * 2.5)

			# Keep the glow vertically alinged w/ the main shape
			shiftBy = (shape.width - params.size.w) / 2
			shape.x = params.coords.x - shiftBy
			shape.y = params.coords.y - shiftBy

			# Clear the canvas beneath the shape
			@clear(shape)

			# Draw the shape on the canvas
			makeShape = @[params.type]
			makeShape(
				shape.x,
				shape.y,
				shape.width,
				shape.height
			)

			# Get the rgba version of color and make opaque
			rgb = utils.hexToRgb(params.color)

			# Fill the glow
			@ctx.save()
			@ctx.fillStyle = "rgba(#{rgb.r}, #{rgb.g}, #{rgb.b}, 0.2)"
			@ctx.fill()
			@ctx.restore()

			# Don't try to clear the canvas again
			params.clear = null


			cb?( shape )

			# Draw the main shape
			@create( params )

			return shape

		#	@glowLeaveAnimation
		# 		Creates a glow around the shape
		#-------------------------------------------------------------------
		glowLeaveAnimation: (params, progress) =>
			# $log.debug('in leave animation')

			# Shape width/height grows outward
			shape =
				width: (params.size.w * (1 - progress)) * 3.2
				height: (params.size.h * (1 - progress)) * 3.2

			# Keep the glow vertically alinged w/ the main shape
			shiftBy = (shape.width - params.size.w) / 2
			shape.x = params.coords.x - shiftBy
			shape.y = params.coords.y - shiftBy

			fullSizeShape =
				width: (params.size.w * 1) * 3.4
				height: (params.size.h * 1) * 3.4

			fullSizeShift = (fullSizeShape.width - params.size.w) / 2
			fullSizeShape.x = params.coords.x - fullSizeShift
			fullSizeShape.y = params.coords.y - fullSizeShift

			# Clear the canvas beneath the shape
			@clear(fullSizeShape)

			# Draw the shape on the canvas
			makeShape = @[params.type]
			makeShape(
				shape.x,
				shape.y,
				shape.width,
				shape.height
			)

			# Get the rgba version of color and make opaque
			rgb = utils.hexToRgb(params.color)

			# Fill the glow
			@ctx.save()
			@ctx.fillStyle = "rgba(#{rgb.r}, #{rgb.g}, #{rgb.b}, 0.2)"
			@ctx.fill()
			@ctx.restore()

			# Don't try to clear the canvas again
			params.clear = null

			# Draw the main shape
			@create( params )

			return fullSizeShape

		#	@fillAnimation
		# 		Fills in the shape from the outside in
		#-------------------------------------------------------------------
		fillAnimation: (params, progress) =>
			shape =
				width: params.size.w - (params.size.w * progress)
				height: params.size.h - (params.size.h * progress)

			shiftBy = (params.size.w - shape.width) / 2

			shape.x = params.coords.x + shiftBy
			shape.y = params.coords.y + shiftBy

			if progress == 0
				@clear( params.clear )

			makeShape = @[params.type]
			makeShape(
				shape.x,
				shape.y,
				shape.width,
				shape.height
			)

			@ctx.save()
			@ctx.strokeStyle = params.color
			@ctx.lineWidth = 1
			@ctx.stroke()
			@ctx.restore()

			return shape

		#	@shadowAnimation
		# 		Adds a shadow beneath the shape
		#-------------------------------------------------------------------
		shadowAnimation: (params, progress) =>
			@clear( params.clear )


			makeShape = @[params.type]
			rgb = utils.hexToRgb(params.color)

			@ctx.save()

			@ctx.shadowColor = 'rgba(0,0,0,0.5)'
			@ctx.shadowBlur = (params.size.h * progress)
			@ctx.shadowOffsetX = 0
			@ctx.shadowOffsetY = (params.size.h * progress)
			@ctx.fillStyle = "rgba(#{rgb.r}, #{rgb.g}, #{rgb.b}, 1)"
			makeShape(params.coords.x, params.coords.y, params.size.w, params.size.h)
			@ctx.fill()

			@ctx.shadowColor = 'rgba(0,0,0,0)'
			@ctx.shadowBlur = 0
			@ctx.shadowOffsetX = 0
			@ctx.shadowOffsetY = 0
			@ctx.lineWidth = 2
			@ctx.strokeStyle = 'rgba(255,255,255,0.8)'
			makeShape(params.coords.x, params.coords.y, params.size.w, params.size.h)
			@ctx.stroke()

			@ctx.restore()

			return {
				x: params.coords.x,
				y: params.coords.y,
				width: params.size.w,
				height: params.size.h
			}


		#	@fadeOutAnimation
		#-------------------------------------------------------------------
		fadeOutAnimation: (params, progress) =>
			@clear( params.clear )

			rgb = utils.hexToRgb(params.color)
			fade = (1 - progress) + 0.2

			makeShape = @[params.type]
			makeShape(params.coords.x, params.coords.y, params.size.w, params.size.h)

			@ctx.save()
			@ctx.fillStyle = "rgba(#{rgb.r}, #{rgb.g}, #{rgb.b}, #{fade})"
			@ctx.strokeStyle = 'rgba(0,0,0,0.0)'
			@ctx.shadowColor = 'rgba(0,0,0,0.0)'
			@ctx.shadowBlur = 0
			@ctx.shadowOffsetX = 0
			@ctx.shadowOffsetY = 0
			@ctx.fill()
			@ctx.restore()

			return {
				x: params.coords.x,
				y: params.coords.y,
				width: params.size.w,
				height: params.size.h
			}

		#	@shakeAnimation
		# 		Creates a shake animation on the shape
		#-------------------------------------------------------------------
		shakeAnimation: (params, progress, cb) =>
			@clear( params.clear )

			makeShape = @[params.type]
			rgb = utils.hexToRgb(params.color)

			direction = if progress < 0.5 then -1 else 1

			rotate = ((progress * 60) - 160) * (Math.PI / 180)

			halfWidth = params.size.w / 2
			halfHeight = params.size.h / 2

			shapeCenter =
				x: params.coords.x + halfWidth
				y: params.coords.y + halfHeight

			shape =
				x: -1 * halfWidth + (15 * direction * (progress/2))
				y: -1 * halfHeight
				w: params.size.w
				h: params.size.h

			@ctx.save()
			@ctx.translate(shapeCenter.x, shapeCenter.y)
			# @ctx.rotate( rotate )
			@ctx.fillStyle = "rgba(#{rgb.r}, #{rgb.g}, #{rgb.b}, 0.9)"
			makeShape(shape.x, shape.y, shape.w, shape.h)
			@ctx.fill()
			@ctx.restore()

			return shape


		#	@confettiAnimation
		# 		Creates a confetti animation
		# 		http://jsfiddle.net/mj3SM/6/
		#-------------------------------------------------------------------
		confettiAnimation: ( params ) ->
			_defaults =
				canvas: null
				totalParticles: 150
				radius: 10
				tilt: 3

			_config = angular.extend({}, _defaults, params)

			return if !_config.canvas?

			W = _config.canvas.width()
			H = _config.canvas.height()

			if params.totalParticles is 'auto'
				largestNum = if H > W then H else W
				_config.totalParticles = Math.ceil( (H * W) / (largestNum * 3) );

			# angle will be an ongoing incremental flag. Sin and Cos functions will be applied to it to create vertical and horizontal movements of the flakes
			angle = 0;
			i = _config.totalParticles
			particles = while i -= 1
				{
					x: Math.random() * W
					y: Math.random() * H
					r: Math.random() * _config.radius + 1
					d: Math.random() * i
					color: "rgba(" + Math.floor((Math.random() * 80)) + ", " + Math.floor((Math.random() * 220)) + ", " + Math.floor((Math.random() * 200)) + ", 1)"
					tilt: Math.floor(Math.random() * _config.tilt) - _config.tilt
				}

			draw = =>
				@ctx.clearRect(0, 0, W + 50, H + 50)

				particles.forEach(( p ) =>
					@ctx.beginPath()
					@ctx.lineWidth = p.r
					@ctx.strokeStyle = p.color
					@ctx.moveTo(p.x, p.y)
					@ctx.lineTo(p.x + p.tilt, p.y + p.tilt)
					@ctx.stroke()
				)

				updateParticles()

				return


			updateParticles = =>
				angle += 0.01;

				particles.forEach(( p, i ) =>
					# Updating X and Y coordinates
					# We will add 1 to the cos function to prevent negative values which will lead flakes to move upwards
					# Every particle has its own density which can be used to make the downward movement different for each flake
					# Lets make it more random by adding in the radius
					p.y += Math.cos(angle + p.d) + 1 + p.r / 2;
					p.x += Math.sin(angle) * 2;

					# Sending flakes back from the top when it exits
					# Lets make it a bit more organic and let flakes enter from the left and right also.
					if p.x > W + 5 || p.x < -5 || p.y > H
						if i % 3 > 0 # 66.67% of the flakes
							particles[i] =
								x: Math.random() * W
								y: -10
								r: p.r
								d: p.d
								color: p.color
								tilt: p.tilt
						else
							# If the flake is exitting from the right
							if Math.sin(angle) > 0
								# Enter from the left
								particles[i] =
									x: -5
									y: Math.random() * H
									r: p.r
									d: p.d
									color: p.color
									tilt: p.tilt
							else
								# Enter from the right
								particles[i] =
									x: W + 5
									y: Math.random() * H
									r: p.r
									d: p.d
									color: p.color
									tilt: p.tilt
				)

			# animation loop
			stop = $interval(draw, 20)

			return stop


		#	@genericCircle
		# 		Creates a basic circle
		#-------------------------------------------------------------------
		genericCircle: (x, y, width, height) =>
			# $log.debug('making circle:', x, y, width, height)
			@ctx.beginPath()

			radius = Math.floor(width / 2)
			centerX = Math.floor( x + ( width / 2 ))
			centerY = Math.floor(y + ( height / 2 ))

			@ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI, false)

			@ctx.closePath()

			return

		#	@genericCircle
		# 		Creates a basic line with rounded caps
		#-------------------------------------------------------------------
		genericLine: (x1, y1, x2, y2) =>
			@ctx.lineCap = 'round'
			@ctx.beginPath()
			@ctx.moveTo(x1, y1)
			@ctx.lineTo(x2, y2)
			@ctx.stroke()

			return

		#	@text
		# 		Writes out a str at a given x or y coord, it can also
		# 		optionally vertically center text in a square
		#
		# 		Params:
		# 			x, y OR x1, y1, x2, y2
		#-------------------------------------------------------------------
		text: ( str, params ) =>
			@ctx.save()

			fontSize = 16
			@ctx.font = fontSize + 'px PT Sans, sans-serif'
			@ctx.textAlign = 'center'
			@ctx.textBaseline = 'top'
			@ctx.fillStyle = '#FFFFFF'

			# If a color has been passed set the fillStyles
			if params.color?
				@ctx.fillStyle = HEXCOLORS[params.color]

			# If both x and y coords have been passed draw the text
			if params.x? and params.y?
				@ctx.fillText('' + str, param.x, params.y)
			else
				# Vertically center the text in the square provided
				x = (params.x1 + params.x2) / 2
				y = (params.y2 + params.y1) / 2
				y -= fontSize / 1.5

				@ctx.fillText('' + str, x, y)

			@ctx.restore()

			return

		#	@dashedLine
		# 		Extends @genericLine to create a dashed line
		#-------------------------------------------------------------------
		dashedLine: (x1, y1, x2, y2) =>
			@ctx.save()
			@ctx.setLineDash([2, 5])
			@ctx.lineWidth = 2
			@ctx.strokeStyle = 'white'
			@genericLine(x1, y1, x2, y2)
			@ctx.restore()

			return

		#	@dashedRedLine
		# 		Extends @genericLine to create a dashed line
		#-------------------------------------------------------------------
		dashedRedLine: (x1, y1, x2, y2) =>
			@ctx.save()
			@ctx.setLineDash([2, 5])
			@ctx.lineWidth = 2
			@ctx.strokeStyle = HEXCOLORS.red
			@genericLine(x1, y1, x2, y2)
			@ctx.restore()

			return

		#	@solidLine
		# 		Extends @genericLine to create a solid line
		#-------------------------------------------------------------------
		solidLine: (x1, y1, x2, y2) =>
			@ctx.save()
			@ctx.lineWidth = 2
			@ctx.strokeStyle = 'white'
			@genericLine(x1, y1, x2, y2)
			@ctx.restore()

			return

		#	@solidRedLine
		# 		Extends @genericLine to create a solid line
		#-------------------------------------------------------------------
		solidRedLine: (x1, y1, x2, y2) =>
			@ctx.save()
			@ctx.lineWidth = 2
			@ctx.strokeStyle = HEXCOLORS.red
			@genericLine(x1, y1, x2, y2)
			@ctx.restore()

			return

		#	@strokedCircle
		# 		Extends @genericCircle to create the circle with a stroke
		#-------------------------------------------------------------------
		strokedCircle: (x, y, width, height, color, spacer) =>
			# $log.debug('making circle:', x, y, width, height)
			circumference = 2 * (Math.PI * (width / 2))
			spacer ?= circumference * 2
			# spacer = 100
			@ctx.save()
			@genericCircle(x, y, width, height)
			@ctx.strokeStyle = HEXCOLORS[color]
			@ctx.lineWidth = SHAPE.BORDER
			@ctx.setLineDash([spacer, circumference])
			@ctx.stroke()
			@ctx.restore()

			return

		#	@circle
		# 		Extends @genericCircle to create the circle used on the
		# 		game board
		#-------------------------------------------------------------------
		circle: (x, y, width, height) =>
			# $log.debug('making circle:', x, y, width, height)
			@genericCircle(x, y, width, height)

			return

		#	@square
		# 		Creates the rounded corner square used on the game board
		#-------------------------------------------------------------------
		square: (x, y, width, height) =>
			# $log.debug('making square:', x, y, width, height, @radius)
			@ctx.beginPath()

			# Start at the top left of the shape
			@ctx.moveTo(x, y + @radius)

			# Draw the left side
			@ctx.lineTo(x, y + height - @radius)

			# Draw the bottom left curve
			@ctx.quadraticCurveTo(x, y + height, x + @radius, y + height)

			# Draw the bottom side
			@ctx.lineTo(x + width - @radius, y + height)

			# Draw the bottom right curve
			@ctx.quadraticCurveTo(x + width, y + height, x + width, y + height - @radius)

			# Draw the right side
			@ctx.lineTo(x + width, y + @radius)

			# Draw the top right curve
			@ctx.quadraticCurveTo(x + width, y, x + width - @radius, y)

			# Draw the top
			@ctx.lineTo(x + @radius, y)

			# Draw the top left curve
			@ctx.quadraticCurveTo(x, y, x, y + @radius)

			@ctx.closePath()

			return

		#	@diamond
		# 		Creates the diamond shape used on the game board
		#-------------------------------------------------------------------
		diamond: (x, y, width, height) =>
			# $log.debug('making diamond:', x, y, width, height)
			@ctx.beginPath()

			# Increase the height + width of the diamond
			# to give it the illusion that it's the same size of other shapes
			width += 2
			height += 2

			# Start at the top center
			@ctx.moveTo(x + (width / 2), y)

			# Draw top left side
			@ctx.lineTo(x, y + (height / 2))

			# Draw bottom left side
			@ctx.lineTo(x + (width / 2), y + height)

			# Draw bottom right side
			@ctx.lineTo(x + width, y + (height / 2))

			# Draw top right side
			@ctx.lineTo(x + (width / 2), y)

			@ctx.closePath()

			return

		#	@triangle
		# 		Creates the rounded edge triangle shape used on the game board
		#-------------------------------------------------------------------
		triangle: (x, y, width, height) =>
			# $log.debug('making triangle', x, y, width, height)
			@ctx.beginPath()

			# Start at the top center
			@ctx.moveTo(x + (width / 2) - @radius, y + @radius)

			# Draw left side
			@ctx.lineTo(x, y + height - @radius)

			# Draw bottom left curve
			@ctx.quadraticCurveTo(x, y + height, x + @radius, y + height)

			# Draw bottom side
			@ctx.lineTo(x + width - @radius, y + height)

			# Draw bottom right curve
			@ctx.quadraticCurveTo(x + width, y + height, x + width, y + height - @radius)

			# Draw right side
			@ctx.lineTo(x + (width / 2) + @radius, y + @radius)

			# Draw top curve
			@ctx.quadraticCurveTo(x + (width / 2), y - @radius, x + (width / 2) - @radius, y + @radius)

			@ctx.closePath()

			return


canvasDrawService.$inject = $requires
module.exports = canvasDrawService
