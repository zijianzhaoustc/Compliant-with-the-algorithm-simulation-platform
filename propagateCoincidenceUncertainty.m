function u=propagateCoincidenceUncertainty(values,covariance,L)
%PROPAGATECOINCIDENCEUNCERTAINTY Full delta method for [C0,Cs,F0,Fs].
validateattributes(covariance,{'numeric'},{'size',[4 4],'finite'});
v=values(:)'; D=v(3)-v(4)/L; N=v(1)-v(2)/L;
pair=N/D; acc=v(1)-v(3)*pair;
gp=[1/D,-1/(L*D),-N/D^2,N/(L*D^2)];
ga=[1,0,-pair,0]-v(3)*gp;
u=struct('pair',pair,'accidental',acc,'gradientPair',gp,'gradientAccidental',ga, ...
    'uPair',sqrt(max(0,gp*covariance*gp')),'uAccidental',sqrt(max(0,ga*covariance*ga')));
end
