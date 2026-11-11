import React from 'react';

export default function Image({
  src,
  alt = '',
  width,
  height,
  className,
  priority: _priority,
  ...props
}: React.ImgHTMLAttributes<HTMLImageElement> & { priority?: boolean }) {
  return <img src={src} alt={alt} width={width} height={height} className={className} {...props} />;
}

